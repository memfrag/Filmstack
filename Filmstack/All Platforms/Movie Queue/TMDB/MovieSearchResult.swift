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
            userNotes: userNotes,
            source: source,
            streamingLocation: streamingLocation,
            status: status
        )
    }
}
