//
//  Filmstack
//

import SwiftUI
import SwiftData

/// Statistics for the Watched section, for one year at a time or for all
/// time, picked with the chips at the top.
///
/// - A year: its total, a recap with highlights and a shareable card, the
///   achievements earned that year, and a month-by-month chart.
/// - All time: the lifetime total, achievements and a year-by-year chart.
///
/// The chart picks a month (or year) whose posters show below it. Every
/// number comes from one `WatchedStats`, so the sections can't disagree.
/// Movies without a watch date are left out.
struct WatchedStatsView: View {

    /// What the screen covers.
    enum Scope: Hashable {
        case year(Int)
        case allTime

        /// Years are charted by month; all time by year.
        var granularity: WatchedStats.Granularity {
            switch self {
            case .year: .month
            case .allTime: .year
            }
        }
    }

    let movies: [Movie]

    @Environment(\.dismiss) private var dismiss

    /// Everything watched; scoped copies are derived from it.
    @State private var stats: WatchedStats
    @State private var scope: Scope
    /// The period picked on the chart; its posters show below it.
    @State private var selectedPeriod: Date?
    /// The written recap headline, shared by the recap and the share card.
    @State private var writtenRecap: YearSummarizer.Written?
    /// The movie opened from a poster, pushed as a detail page in the sheet.
    @State private var pushedMovie: Movie?

    init(movies: [Movie]) {
        self.movies = movies
        let stats = WatchedStats(entries: movies.compactMap(\.watchedEntry))
        let scope = Self.defaultScope(for: stats)
        _stats = State(initialValue: stats)
        _scope = State(initialValue: scope)
        _selectedPeriod = State(initialValue: Self.scoped(stats, to: scope).latestActive(scope.granularity))
    }

    /// The most recent year with anything watched.
    private static func defaultScope(for stats: WatchedStats) -> Scope {
        stats.watchedYears.first.map(Scope.year) ?? .allTime
    }

    private static func scoped(_ stats: WatchedStats, to scope: Scope) -> WatchedStats {
        switch scope {
        case .year(let year): stats.scoped(toYear: year)
        case .allTime: stats
        }
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
            if case .year(let year) = scope, !stats.watchedYears.contains(year) {
                select(Self.defaultScope(for: stats))
            } else if let selectedPeriod,
                      !Self.scoped(stats, to: scope).counts(scope.granularity).contains(where: { $0.start == selectedPeriod }) {
                self.selectedPeriod = Self.scoped(stats, to: scope).latestActive(scope.granularity)
            }
        }
    }

    @ViewBuilder private var content: some View {
        let lookup = moviesByID
        let movie: (UUID) -> Movie? = { lookup[$0] }
        let open: (UUID) -> Void = { id in pushedMovie = lookup[id] }
        let scoped = Self.scoped(stats, to: scope)
        let granularity = scope.granularity

        VStack(alignment: .leading, spacing: 24) {
            ScopePicker(years: stats.watchedYears, selection: Binding(get: { scope }, set: select))

            StatsHeroSection(stats: scoped, scope: scope, previousYearCount: previousYearCount)

            if case .year(let year) = scope {
                let facts = stats.facts(forYear: year)
                if facts.count >= WatchedStats.recapMinimum {
                    YearRecapSection(stats: stats, facts: facts, personality: stats.personality(forYear: year),
                                     written: $writtenRecap, movie: movie, onOpen: open)
                        .id(year)
                }
            }

            AchievementsSection(title: achievementsTitle, achievements: scoped.achievements)

            // Everything watched that year, before the month-by-month view.
            if let yearStart = scoped.span?.start {
                PosterHistorySection(stats: scoped, granularity: .year, period: yearStart,
                                     movie: movie, onOpen: open)
                    .id(yearStart)
            }

            VStack(alignment: .leading, spacing: 16) {
                ActivityChartSection(stats: scoped, granularity: granularity, selection: $selectedPeriod)
                if let selectedPeriod {
                    // Overlapping layers, so the old and new period cross-fade
                    // in place instead of stacking.
                    ZStack(alignment: .topLeading) {
                        PosterHistorySection(stats: scoped, granularity: granularity, period: selectedPeriod,
                                             movie: movie, onOpen: open)
                            .id(selectedPeriod)
                            .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
                }
            }

            if case .year(let year) = scope {
                let facts = stats.facts(forYear: year)
                if facts.count >= WatchedStats.recapMinimum {
                    ShareRecapSection(content: ShareRecapContent(
                        facts: facts,
                        headline: writtenRecap?.headline,
                        topRatedMovie: facts.topRated.flatMap { lookup[$0.id] }))
                }
            }
        }
        .padding(20)
    }

    private var achievementsTitle: LocalizedStringKey {
        switch scope {
        case .year(let year): "Achievements in \(String(year))"
        case .allTime: "Achievements"
        }
    }

    /// Movies watched the year before the selected one, when there were any.
    private var previousYearCount: Int? {
        guard case .year(let year) = scope else { return nil }
        let count = stats.count(inYear: year - 1)
        return count > 0 ? count : nil
    }

    private func select(_ newScope: Scope) {
        guard newScope != scope else { return }
        withAnimation(.smooth(duration: 0.3)) {
            scope = newScope
            writtenRecap = nil
            selectedPeriod = Self.scoped(stats, to: newScope).latestActive(newScope.granularity)
        }
    }
}

/// All Time, then a chip for each year with movies watched, most recent first.
private struct ScopePicker: View {

    let years: [Int]
    @Binding var selection: WatchedStatsView.Scope

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(String(localized: "All Time"), scope: .allTime)
                ForEach(years, id: \.self) { year in
                    chip(String(year), scope: .year(year))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(_ title: String, scope: WatchedStatsView.Scope) -> some View {
        let isSelected = selection == scope
        return Button { selection = scope } label: {
            Text(title)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(isSelected ? .white : Palette.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(Gradients.selectedRow) : AnyShapeStyle(Palette.card))
                }
                .overlay { Capsule().strokeBorder(isSelected ? .white.opacity(0.18) : Palette.hairline) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#if DEBUG
#Preview {
    WatchedStatsView(movies: SampleMovies.makeMovies())
        .modelContainer(MovieStore.previewContainer)
}
#endif
