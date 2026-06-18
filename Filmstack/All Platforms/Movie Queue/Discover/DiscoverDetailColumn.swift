//
//  Filmstack
//

import SwiftUI
import SwiftData
import NukeUI

/// Detail pane for a movie picked from a Discover list. Shows the movie
/// cinematically and offers an Add action, fetching full details on appear.
struct DiscoverDetailColumn: View {

    let result: MovieSearchResult

    @Environment(AppSettings.self) private var appSettings
    @Environment(\.modelContext) private var context

    enum Phase {
        case loading
        case loaded(MovieDetails)
        case failed(String)
    }

    @State private var phase: Phase = .loading
    /// Status of this movie if it's already in the library.
    @State private var existingStatus: MovieStatus?
    /// Status it was just added as, this session.
    @State private var addedStatus: MovieStatus?
    @State private var confirmWatchedAgain = false

    private let heroHeight: CGFloat = 220
    private var region: String? { appSettings.releaseRegion }

    private var details: MovieDetails? {
        if case .loaded(let details) = phase { return details }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    posterAndTitle
                        .padding(.horizontal, 24)
                        .padding(.top, -90)
                    sections
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            actionBar
        }
        .background(Palette.base)
        .task(id: result.id) { await load() }
        .confirmationDialog(
            "You already watched this movie. Add it again?",
            isPresented: $confirmWatchedAgain,
            titleVisibility: .visible
        ) {
            Button("Add Again") { add(.queued, force: true) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            heroImage
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay { Gradients.heroScrim() }
        }
        .frame(height: heroHeight)
    }

    @ViewBuilder private var heroImage: some View {
        if let backdrop = TMDBImage.backdropURL(path: details?.backdropPath) {
            LazyImage(url: backdrop) { state in
                if let image = state.image { image.resizable().scaledToFill() } else { Gradients.hero }
            }
        } else if let poster = TMDBImage.posterURL(path: result.posterPath, size: .detail) {
            LazyImage(url: poster) { state in
                if let image = state.image {
                    image.resizable().scaledToFill().blur(radius: 38).opacity(0.55)
                } else {
                    Gradients.hero
                }
            }
        } else {
            Gradients.hero
        }
    }

    // MARK: - Poster + title

    private var posterAndTitle: some View {
        HStack(alignment: .bottom, spacing: 18) {
            poster
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 132)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 14, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                if let rating = details?.tmdbRating {
                    RatingBadge(rating: rating)
                }
                Text(result.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let meta = metaLine {
                    Text(meta).font(.callout).foregroundStyle(Palette.textSecondary)
                }
                if let genres = details?.genres, !genres.isEmpty {
                    Text(genres.joined(separator: ", "))
                        .font(.callout)
                        .foregroundStyle(Palette.textSecondary)
                }
                if let director = details?.director, !director.isEmpty {
                    labeledField("Director", director).padding(.top, 4)
                }
            }
            .padding(.bottom, 6)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var poster: some View {
        if let url = TMDBImage.posterURL(path: result.posterPath, size: .detail) {
            LazyImage(url: url) { state in
                if let image = state.image { image.resizable().scaledToFill() } else { posterPlaceholder }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle().fill(.fill.tertiary)
            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
    }

    private var metaLine: String? {
        var parts: [String] = []
        if let year = result.releaseYear { parts.append(String(year)) }
        if let runtime = details?.runtimeMinutes, runtime > 0 {
            let h = runtime / 60, m = runtime % 60
            parts.append(h > 0 ? "\(h)h \(m)m" : "\(m)m")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Sections

    @ViewBuilder private var sections: some View {
        if case .failed(let message) = phase {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Palette.textSecondary)
        }
        if let overview = result.overview, !overview.isEmpty {
            section("Overview") { Text(overview) }
        }
        if let cast = details?.cast, !cast.isEmpty {
            section("Cast") { Text(cast.joined(separator: ", ")) }
        }
        if let providers = details?.watchProviders, !providers.isEmpty {
            section("Where to Watch") {
                Text(providers.filter { $0.access == .stream }.map(\.name).joined(separator: ", "))
            }
        }
    }

    private func labeledField(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(Palette.accentBright)
            Text(value).font(.subheadline).foregroundStyle(Palette.textPrimary)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased()).font(.caption.bold()).foregroundStyle(Palette.accentBright)
            content().font(.body).foregroundStyle(Palette.textPrimary.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 12) {
            if let status = addedStatus ?? nonWatchedExisting {
                Label("In \(status.title)", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button {
                    add(.queued)
                } label: {
                    Label("Add to Queue", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.filmAccent)
                .disabled(details == nil)

                Menu {
                    Button("Add to Maybe Later") { add(.maybeLater) }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .menuStyle(.button)
                .buttonStyle(.filmGlass)
                .fixedSize()
                .disabled(details == nil)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 1) }
    }

    /// The existing non-watched status (queued/maybeLater) if already in library.
    private var nonWatchedExisting: MovieStatus? {
        (existingStatus == .queued || existingStatus == .maybeLater) ? existingStatus : nil
    }

    // MARK: - Loading & adding

    private func load() async {
        phase = .loading
        addedStatus = nil
        existingStatus = currentExistingStatus()
        do {
            let details = try await AppEnvironment.default.movieAPIClient
                .fetchMovieDetails(tmdbID: result.tmdbID, region: region)
            phase = .loaded(details)
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func add(_ status: MovieStatus, force: Bool = false) {
        guard case .loaded(let details) = phase else { return }
        if !force {
            let existing = existingMovies()
            if existing.contains(where: { $0.status == .queued || $0.status == .maybeLater }) {
                existingStatus = currentExistingStatus()
                return
            }
            if existing.contains(where: { $0.status == .watched }) {
                confirmWatchedAgain = true
                return
            }
        }
        let movie = Movie(details: details, status: status)
        MovieActions.add(movie, in: context)
        addedStatus = status
    }

    private func existingMovies() -> [Movie] {
        let tmdbID = result.tmdbID
        let descriptor = FetchDescriptor<Movie>(predicate: #Predicate { $0.tmdbID == tmdbID })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func currentExistingStatus() -> MovieStatus? {
        let movies = existingMovies()
        if let queued = movies.first(where: { $0.status == .queued }) { return queued.status }
        if let later = movies.first(where: { $0.status == .maybeLater }) { return later.status }
        return movies.first?.status
    }
}
