//
//  Filmstack
//

import Foundation

/// A single TMDB search hit, before it's saved to the library.
struct MovieSearchResult: Identifiable, Codable, Sendable, Hashable {
    var id: Int { tmdbID }
    var tmdbID: Int
    var title: String
    var originalTitle: String?
    var releaseDate: Date?
    var releaseYear: Int?
    var overview: String?
    var posterPath: String?
    var posterThumbnailURL: URL?
}

/// Full TMDB movie details, fetched after the user selects a search result.
struct MovieDetails: Codable, Sendable {
    var tmdbID: Int
    var title: String
    var originalTitle: String?
    var releaseDate: Date?
    var releaseYear: Int?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var runtimeMinutes: Int?
    var genres: [String]
    var director: String?
    /// Top-billed cast member names, in billing order.
    var cast: [String]
    /// TMDB community rating (0–10).
    var tmdbRating: Double?
    var imdbID: String?
    /// Streaming providers for the requested region (JustWatch via TMDB).
    var watchProviders: [WatchProvider]
    /// JustWatch availability page for the requested region.
    var watchLink: URL?

    init(
        tmdbID: Int,
        title: String,
        originalTitle: String? = nil,
        releaseDate: Date? = nil,
        releaseYear: Int? = nil,
        overview: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        runtimeMinutes: Int? = nil,
        genres: [String] = [],
        director: String? = nil,
        cast: [String] = [],
        tmdbRating: Double? = nil,
        imdbID: String? = nil,
        watchProviders: [WatchProvider] = [],
        watchLink: URL? = nil
    ) {
        self.tmdbID = tmdbID
        self.title = title
        self.originalTitle = originalTitle
        self.releaseDate = releaseDate
        self.releaseYear = releaseYear
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.runtimeMinutes = runtimeMinutes
        self.genres = genres
        self.director = director
        self.cast = cast
        self.tmdbRating = tmdbRating
        self.imdbID = imdbID
        self.watchProviders = watchProviders
        self.watchLink = watchLink
    }
}

extension Movie {
    /// Creates a queued `Movie` from fetched TMDB details, carrying over optional
    /// user-entered fields.
    convenience init(
        details: MovieDetails,
        userNotes: String = "",
        source: String? = nil,
        streamingLocation: String? = nil,
        status: MovieStatus = .queued
    ) {
        self.init(
            title: details.title,
            tmdbID: details.tmdbID,
            originalTitle: details.originalTitle,
            releaseDate: details.releaseDate,
            releaseYear: details.releaseYear,
            overview: details.overview,
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            runtimeMinutes: details.runtimeMinutes,
            genres: details.genres,
            director: details.director,
            cast: details.cast,
            tmdbRating: details.tmdbRating,
            watchProviders: details.watchProviders,
            justWatchURL: details.watchLink,
            imdbID: details.imdbID,
            userNotes: userNotes,
            source: source,
            streamingLocation: streamingLocation,
            status: status
        )
    }
}
