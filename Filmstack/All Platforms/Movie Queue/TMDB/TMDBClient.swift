//
//  Filmstack
//

import Foundation

/// Live TMDB implementation of `MovieAPIClient` using `URLSession` and a Bearer
/// Read Access Token loaded from the Keychain.
///
/// Credentials are sent only in the `Authorization` header (never in query
/// parameters) and are never logged.
final class TMDBClient: MovieAPIClient {

    private let keyStore: any APIKeyStore
    private let session: URLSession
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    init(keyStore: any APIKeyStore, session: URLSession = .shared) {
        self.keyStore = keyStore
        self.session = session
    }

    // MARK: - Search

    func searchMovies(query: String) async throws -> [MovieSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let data = try await get("search/movie", queryItems: [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1")
        ])

        let response = try decode(SearchResponse.self, from: data)
        return response.results.map { item in
            let parsed = Self.parseReleaseDate(item.releaseDate)
            return MovieSearchResult(
                tmdbID: item.id,
                title: item.title,
                originalTitle: item.originalTitle,
                releaseDate: parsed.date,
                releaseYear: parsed.year,
                overview: item.overview?.nilIfBlank,
                posterPath: item.posterPath,
                posterThumbnailURL: TMDBImage.posterURL(path: item.posterPath, size: .thumbnail)
            )
        }
    }

    // MARK: - Details

    func fetchMovieDetails(tmdbID: Int) async throws -> MovieDetails {
        let data = try await get("movie/\(tmdbID)", queryItems: [
            URLQueryItem(name: "language", value: "en-US")
        ])

        let response = try decode(DetailsResponse.self, from: data)
        let parsed = Self.parseReleaseDate(response.releaseDate)
        return MovieDetails(
            tmdbID: response.id,
            title: response.title,
            originalTitle: response.originalTitle,
            releaseDate: parsed.date,
            releaseYear: parsed.year,
            overview: response.overview?.nilIfBlank,
            posterPath: response.posterPath,
            backdropPath: response.backdropPath,
            runtimeMinutes: response.runtime.flatMap { $0 > 0 ? $0 : nil },
            genres: response.genres.map(\.name)
        )
    }

    // MARK: - Posters

    func posterURL(path: String, size: PosterSize) -> URL? {
        TMDBImage.posterURL(path: path, size: size)
    }

    // MARK: - Token validation

    func validateToken(_ token: String) async throws -> Bool {
        var request = URLRequest(url: baseURL.appending(path: "configuration"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        switch http.statusCode {
        case 200: return true
        case 401: return false
        case 429: throw TMDBError.rateLimited
        case 500...599: throw TMDBError.serviceUnavailable
        default: throw TMDBError.requestFailed(statusCode: http.statusCode)
        }
    }

    // MARK: - Request plumbing

    private func get(_ path: String, queryItems: [URLQueryItem]) async throws -> Data {
        guard let token = try keyStore.loadTMDBToken(), !token.isEmpty else {
            throw TMDBError.missingAPIKey
        }

        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: return data
        case 401: throw TMDBError.invalidToken
        case 429: throw TMDBError.rateLimited
        case 500...599: throw TMDBError.serviceUnavailable
        default: throw TMDBError.requestFailed(statusCode: http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw TMDBError.invalidResponse
        }
    }

    /// Parses TMDB's "yyyy-MM-dd" date string without a (non-Sendable) shared
    /// `DateFormatter`.
    private static func parseReleaseDate(_ string: String?) -> (date: Date?, year: Int?) {
        guard let string, !string.isEmpty else { return (nil, nil) }
        let parts = string.split(separator: "-")
        guard let year = parts.first.flatMap({ Int($0) }) else { return (nil, nil) }

        var components = DateComponents()
        components.year = year
        if parts.count > 1 { components.month = Int(parts[1]) }
        if parts.count > 2 { components.day = Int(parts[2]) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return (calendar.date(from: components), year)
    }
}

// MARK: - TMDB response DTOs

private struct SearchResponse: Decodable {
    let results: [Item]

    struct Item: Decodable {
        let id: Int
        let title: String
        let originalTitle: String?
        let overview: String?
        let posterPath: String?
        let releaseDate: String?

        enum CodingKeys: String, CodingKey {
            case id, title, overview
            case originalTitle = "original_title"
            case posterPath = "poster_path"
            case releaseDate = "release_date"
        }
    }
}

private struct DetailsResponse: Decodable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let runtime: Int?
    let releaseDate: String?
    let genres: [Genre]

    struct Genre: Decodable {
        let name: String
    }

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
