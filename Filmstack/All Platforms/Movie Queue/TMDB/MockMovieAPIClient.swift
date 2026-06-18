//
//  Filmstack
//

#if DEBUG

import Foundation

/// In-memory `APIKeyStore` for previews and tests.
final class InMemoryAPIKeyStore: APIKeyStore, @unchecked Sendable {

    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func saveTMDBToken(_ token: String) throws {
        lock.withLock { self.token = token }
    }

    func loadTMDBToken() throws -> String? {
        lock.withLock { token }
    }

    func deleteTMDBToken() throws {
        lock.withLock { token = nil }
    }
}

/// Canned `MovieAPIClient` for previews and tests. Returns sample results without
/// touching the network.
final class MockMovieAPIClient: MovieAPIClient {

    var results: [MovieSearchResult]

    init(results: [MovieSearchResult]? = nil) {
        self.results = results ?? Self.defaultResults
    }

    func searchMovies(query: String) async throws -> [MovieSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return results.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    func fetchMovieDetails(tmdbID: Int, region: String?) async throws -> MovieDetails {
        let result = results.first { $0.tmdbID == tmdbID }
        return MovieDetails(
            tmdbID: tmdbID,
            title: result?.title ?? "Sample Movie",
            originalTitle: result?.originalTitle,
            releaseDate: result?.releaseDate,
            releaseYear: result?.releaseYear,
            overview: result?.overview,
            posterPath: result?.posterPath,
            backdropPath: nil,
            runtimeMinutes: 120,
            genres: ["Drama"],
            director: "Sample Director",
            cast: ["First Actor", "Second Actor", "Third Actor"],
            tmdbRating: 7.8,
            imdbID: nil,
            watchProviders: Self.sampleProviders,
            watchLink: nil
        )
    }

    func fetchWatchProviders(tmdbID: Int, region: String?) async throws -> WatchAvailability {
        WatchAvailability(providers: Self.sampleProviders, link: nil)
    }

    private static let sampleProviders: [WatchProvider] = [
        WatchProvider(name: "Sample Stream", logoPath: nil, access: .stream),
        WatchProvider(name: "Sample Rental", logoPath: nil, access: .rent),
        WatchProvider(name: "Sample Store", logoPath: nil, access: .buy)
    ]

    func posterURL(path: String, size: PosterSize) -> URL? {
        TMDBImage.posterURL(path: path, size: size)
    }

    func validateToken(_ token: String) async throws -> Bool {
        !token.isEmpty
    }

    static let defaultResults: [MovieSearchResult] = [
        MovieSearchResult(
            tmdbID: 693134,
            title: "Dune: Part Two",
            releaseYear: 2024,
            overview: "Paul Atreides unites with Chani and the Fremen.",
            posterPath: "/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg",
            posterThumbnailURL: TMDBImage.posterURL(
                path: "/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg",
                size: .thumbnail
            )
        ),
        MovieSearchResult(
            tmdbID: 496243,
            title: "Parasite",
            releaseYear: 2019,
            overview: "A poor family schemes to become employed by a wealthy household."
        )
    ]
}

#endif
