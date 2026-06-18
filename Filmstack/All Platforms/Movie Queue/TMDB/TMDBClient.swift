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

    func fetchMovieDetails(tmdbID: Int, region: String?) async throws -> MovieDetails {
        let data = try await get("movie/\(tmdbID)", queryItems: [
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "append_to_response", value: "credits,release_dates,watch/providers")
        ])

        let response = try decode(DetailsResponse.self, from: data)
        let primary = Self.parseReleaseDate(response.releaseDate)
        let watch = response.watchProviders?.streaming(forRegion: region)

        // Prefer a local release date for the given region, keeping the canonical
        // (primary) year for display.
        var effectiveDate = primary.date
        if let regionString = response.releaseDates?.preferredReleaseString(region: region),
           let regional = Self.parseReleaseDate(String(regionString.prefix(10))).date {
            effectiveDate = regional
        }

        return MovieDetails(
            tmdbID: response.id,
            title: response.title,
            originalTitle: response.originalTitle,
            releaseDate: effectiveDate,
            releaseYear: primary.year,
            overview: response.overview?.nilIfBlank,
            posterPath: response.posterPath,
            backdropPath: response.backdropPath,
            runtimeMinutes: response.runtime.flatMap { $0 > 0 ? $0 : nil },
            genres: response.genres.map(\.name),
            director: response.credits?.directors,
            cast: response.credits?.topBilledCast(limit: Self.castLimit) ?? [],
            tmdbRating: response.voteAverage.flatMap { $0 > 0 ? $0 : nil },
            imdbID: response.imdbID?.nilIfBlank,
            watchProviders: watch?.providers ?? [],
            watchLink: watch?.link
        )
    }

    /// Number of top-billed cast members to keep.
    private static let castLimit = 8

    // MARK: - Watch providers

    func fetchWatchProviders(tmdbID: Int, region: String?) async throws -> WatchAvailability {
        let data = try await get("movie/\(tmdbID)/watch/providers", queryItems: [])
        let response = try decode(WatchProvidersResponse.self, from: data)
        let resolved = response.streaming(forRegion: region)
        return WatchAvailability(providers: resolved.providers, link: resolved.link)
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
    let credits: Credits?
    let voteAverage: Double?
    let imdbID: String?
    let releaseDates: ReleaseDates?
    let watchProviders: WatchProvidersResponse?

    struct Genre: Decodable {
        let name: String
    }

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case imdbID = "imdb_id"
        case releaseDates = "release_dates"
        case watchProviders = "watch/providers"
    }
}

private struct WatchProvidersResponse: Decodable {
    let results: [String: RegionProviders]

    struct RegionProviders: Decodable {
        let link: String?
        let flatrate: [Provider]?
        let free: [Provider]?
        let ads: [Provider]?
    }

    struct Provider: Decodable {
        let providerName: String
        let logoPath: String?
        let displayPriority: Int?

        enum CodingKeys: String, CodingKey {
            case providerName = "provider_name"
            case logoPath = "logo_path"
            case displayPriority = "display_priority"
        }
    }

    /// Streaming providers (subscription, free, ad-supported) for a region, with
    /// the region's JustWatch link. Rent/buy are intentionally excluded.
    func streaming(forRegion region: String?) -> (link: URL?, providers: [WatchProvider]) {
        guard let region,
              let regionProviders = results[region.uppercased()] ?? results[region]
        else { return (nil, []) }

        var seen = Set<String>()
        var providers: [WatchProvider] = []
        for bucket in [regionProviders.flatrate, regionProviders.free, regionProviders.ads] {
            let sorted = (bucket ?? []).sorted { ($0.displayPriority ?? .max) < ($1.displayPriority ?? .max) }
            for provider in sorted where seen.insert(provider.providerName).inserted {
                providers.append(WatchProvider(name: provider.providerName, logoPath: provider.logoPath))
            }
        }
        return (regionProviders.link.flatMap(URL.init(string:)), providers)
    }
}

private struct ReleaseDates: Decodable {
    let results: [CountryReleases]

    struct CountryReleases: Decodable {
        let iso31661: String
        let releaseDates: [Release]

        enum CodingKeys: String, CodingKey {
            case iso31661 = "iso_3166_1"
            case releaseDates = "release_dates"
        }
    }

    struct Release: Decodable {
        let type: Int
        let releaseDate: String

        enum CodingKeys: String, CodingKey {
            case type
            case releaseDate = "release_date"
        }
    }

    /// The preferred release-date string for a region, by release-type priority:
    /// theatrical → limited → premiere → digital → physical → TV, then earliest.
    func preferredReleaseString(region: String?) -> String? {
        guard let region,
              let country = results.first(where: { $0.iso31661.caseInsensitiveCompare(region) == .orderedSame })
        else { return nil }

        let priority = [3, 2, 1, 4, 5, 6]
        for type in priority {
            if let release = country.releaseDates.first(where: { $0.type == type }) {
                return release.releaseDate
            }
        }
        return country.releaseDates.map(\.releaseDate).min()
    }
}

private struct Credits: Decodable {
    let cast: [CastMember]
    let crew: [CrewMember]

    struct CastMember: Decodable {
        let name: String
        let order: Int?
    }

    struct CrewMember: Decodable {
        let name: String
        let job: String?
    }

    /// All directors, joined (handles co-directors like the Coen brothers).
    var directors: String? {
        let names = crew.filter { $0.job == "Director" }.map(\.name)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    /// Top-billed cast names, in billing order.
    func topBilledCast(limit: Int) -> [String] {
        cast
            .sorted { ($0.order ?? .max) < ($1.order ?? .max) }
            .prefix(limit)
            .map(\.name)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
