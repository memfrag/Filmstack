//
//  Filmstack
//

import SwiftUI
import SwiftData
import OSLog

/// Fetches the extra TMDB context (keywords, tagline, age rating, language)
/// once for library movies added before it was stored, then clears their
/// mood tags so they're retagged with it.
///
/// Attach once near the root with `.movieContextBackfill()`. Runs quietly in
/// the background and stops without a TMDB key or on errors, trying again on
/// the next launch.
struct MovieContextBackfillModifier: ViewModifier {

    @Query(filter: #Predicate<Movie> { $0.contextFetchedAt == nil && $0.tmdbID != nil })
    private var missing: [Movie]

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var appSettings

    private static let logger = Logger(subsystem: "io.apparata.Filmstack", category: "AI")

    func body(content: Content) -> some View {
        content
            .task(id: missing.isEmpty) { await backfill() }
    }

    private func backfill() async {
        let client = AppEnvironment.default.movieAPIClient
        let region = appSettings.releaseRegion
        let descriptor = FetchDescriptor<Movie>(
            predicate: #Predicate { $0.contextFetchedAt == nil && $0.tmdbID != nil }
        )
        guard let movies = try? context.fetch(descriptor) else { return }
        for movie in movies {
            guard !Task.isCancelled, let tmdbID = movie.tmdbID else { return }
            do {
                let details = try await client.fetchMovieDetails(tmdbID: tmdbID, region: region)
                movie.applyContext(from: details)
                if !details.keywords.isEmpty || details.tagline != nil {
                    movie.moodsTaggedAt = nil  // retag with the new context
                }
                try? context.save()
                // Stay well inside TMDB's rate limit.
                try await Task.sleep(for: .milliseconds(250))
            } catch is CancellationError {
                return
            } catch {
                Self.logger.error("Context backfill stopped: \(String(describing: error), privacy: .public)")
                return
            }
        }
    }
}

extension View {
    /// Fetches missing TMDB context for older library movies.
    func movieContextBackfill() -> some View {
        modifier(MovieContextBackfillModifier())
    }
}
