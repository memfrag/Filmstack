//
//  Filmstack
//

import Foundation

/// Abstracts the movie metadata provider (TMDB) so the UI and tests can depend on
/// a protocol rather than the concrete network client.
protocol MovieAPIClient: Sendable {
    func searchMovies(query: String) async throws -> [MovieSearchResult]
    /// Fetches full details. `region` is an ISO 3166-1 code used to prefer a local
    /// release date; pass `nil` to use TMDB's primary release date.
    func fetchMovieDetails(tmdbID: Int, region: String?) async throws -> MovieDetails
    /// Re-fetches just the streaming availability for a region (it changes over time).
    func fetchWatchProviders(tmdbID: Int, region: String?) async throws -> WatchAvailability
    /// Fetches a TMDB discover list (now playing, popular, top rated, upcoming).
    func fetchDiscover(list: DiscoverList, region: String?) async throws -> [MovieSearchResult]
    func posterURL(path: String, size: PosterSize) -> URL?
    func validateToken(_ token: String) async throws -> Bool
}

/// Errors surfaced by `MovieAPIClient` implementations. Messages are user-facing.
enum TMDBError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidToken
    case rateLimited
    case serviceUnavailable
    case requestFailed(statusCode: Int)
    case invalidResponse
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Movie search requires a TMDB API key."
        case .invalidToken:
            "Your TMDB API key appears to be invalid."
        case .rateLimited:
            "TMDB is busy right now. Please try again in a moment."
        case .serviceUnavailable:
            "TMDB is currently unavailable. You can still add a movie manually."
        case .requestFailed(let statusCode):
            "Something went wrong talking to TMDB (code \(statusCode))."
        case .invalidResponse:
            "Received an unexpected response from TMDB."
        case .invalidURL:
            "Could not build the request to TMDB."
        }
    }
}
