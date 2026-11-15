//
//  Filmstack
//

import SwiftUI
import SwiftData

/// Statistics for the Watched section: the total and supporting numbers, a
/// recap of the year, achievements, an interactive chart of movies watched
/// per month or year, posters from the picked period, and a shareable card.
///
/// Every number comes from one `WatchedStats`, computed when the movies
/// change, so the sections can't disagree. Movies without a watch date are
/// left out.
struct WatchedStatsView: View {

    let movies: [Movie]

    @Environment(\.dismiss) private var dismiss

    @State private var stats: WatchedStats
    @State private var granularity: WatchedStats.Granularity = .month
    /// The period picked on the chart; its posters show below it.
    @State private var selectedPeriod: Date?
    /// The written recap headline, shared by the recap and the share card.
    @State private var writtenRecap: YearSummarizer.Written?
    /// The movie opened from a poster, pushed as a detail page in the sheet.
    @State private var pushedMovie: Movie?

    init(movies: [Movie]) {
        self.movies = movies
        let stats = WatchedStats(entries: movies.compactMap(\.watchedEntry))
        _stats = State(initialValue: stats)
        _selectedPeriod = State(initialValue: stats.latestActive(.month))
    }

    /// Changes whenever anything the statistics use changes.
    private var moviesSignature: Int {
        var hasher = Hasher()
        for movie in movies {
            hasher.combine(movie.watchedEntry)
            hasher.combine(movie.posterPath)
        }
        return hasher.finalize()
    }

    private var moviesByID: [UUID: Movie] {
        Dictionary(movies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if stats.isEmpty {
                    ContentUnavailableView(
                        "No Watch Dates",
                        systemImage: "chart.bar",
                        description: Text("Movies you mark as watched show up here by month.")
                    )
                    .padding(.top, 60)
                } else {
                    content
                }
            }
            .filmWindowBackground()
            .navigationTitle("Statistics")
            .navigationDestination(item: $pushedMovie) { _ in
                MovieDetailColumn(selection: $pushedMovie)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
        .onChange(of: moviesSignature) {
            stats = WatchedStats(entries: movies.compactMap(\.watchedEntry))
            if let selectedPeriod, !stats.counts(granularity).contains(where: { $0.start == selectedPeriod }) {
                self.selectedPeriod = stats.latestActive(granularity)
            }
        }
    }

    @ViewBuilder private var content: some View {
        let lookup = moviesByID
        let movie: (UUID) -> Movie? = { lookup[$0] }
        let open: (UUID) -> Void = { id in pushedMovie = lookup[id] }
        let recapYear = stats.recapYear
        let facts = recapYear.map { stats.facts(forYear: $0) }

        VStack(alignment: .leading, spacing: 24) {
            periodPicker
            StatsHeroSection(stats: stats, granularity: granularity)

            if let facts, let year = recapYear {
                YearRecapSection(stats: stats, facts: facts, personality: stats.personality(forYear: year),
                                 written: $writtenRecap, movie: movie, onOpen: open)
                    .id(year)
            }

            AchievementsSection(achievements: stats.achievements)

            VStack(alignment: .leading, spacing: 16) {
                ActivityChartSection(stats: stats, granularity: granularity, selection: $selectedPeriod)
                if let selectedPeriod {
                    // Overlapping layers, so the old and new period cross-fade
                    // in place instead of stacking.
                    ZStack(alignment: .topLeading) {
                        PosterHistorySection(stats: stats, granularity: granularity, period: selectedPeriod,
                                             movie: movie, onOpen: open)
                            .id(selectedPeriod)
                            .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
                }
            }

            if let facts {
                ShareRecapSection(content: ShareRecapContent(
                    facts: facts,
                    headline: writtenRecap?.headline,
                    topRatedMovie: facts.topRated.flatMap { lookup[$0.id] }))
            }
        }
        .padding(20)
    }

    private var periodPicker: some View {
        Picker("Period", selection: $granularity) {
            Text("By Month").tag(WatchedStats.Granularity.month)
            Text("By Year").tag(WatchedStats.Granularity.year)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .sensoryFeedback(.selection, trigger: granularity)
        .onChange(of: granularity) {
            withAnimation(.smooth(duration: 0.3)) {
                selectedPeriod = stats.latestActive(granularity)
            }
        }
    }
}

#if DEBUG
#Preview {
    WatchedStatsView(movies: SampleMovies.makeMovies())
        .modelContainer(MovieStore.previewContainer)
}
#endif
