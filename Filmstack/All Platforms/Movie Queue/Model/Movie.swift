//
//  Filmstack
//

import Foundation
import SwiftData

/// A movie in the user's personal library.
///
/// Persisted locally with SwiftData. `status` is stored as a raw string
/// (`statusRawValue`) so it can be used in `#Predicate` filters, with a typed
/// `status` accessor layered on top.
@Model
final class Movie {

    // Identity
    var id: UUID = UUID()

    // External metadata (TMDB)
    var tmdbID: Int?
    var title: String = ""
    var originalTitle: String?
    var releaseDate: Date?
    var releaseYear: Int?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var runtimeMinutes: Int?
    var genres: [String] = []
    var director: String?
    var cast: [String] = []
    /// TMDB community rating (0–10).
    var tmdbRating: Double?

    // Streaming availability (TMDB watch/providers, powered by JustWatch)
    var watchProviders: [WatchProvider] = []
    var justWatchURLString: String?

    // Optional external links
    var imdbID: String?
    var letterboxdURLString: String?

    // User-owned fields
    var userNotes: String = ""
    var source: String?
    var streamingLocation: String?
    var rating: Int?

    // Queue state
    var statusRawValue: String = MovieStatus.queued.rawValue
    var queuePosition: Int?
    var dateAdded: Date = Date()
    var dateWatched: Date?

    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        title: String,
        tmdbID: Int? = nil,
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
        watchProviders: [WatchProvider] = [],
        justWatchURL: URL? = nil,
        imdbID: String? = nil,
        letterboxdURL: URL? = nil,
        userNotes: String = "",
        source: String? = nil,
        streamingLocation: String? = nil,
        rating: Int? = nil,
        status: MovieStatus = .queued,
        queuePosition: Int? = nil,
        dateAdded: Date = Date(),
        dateWatched: Date? = nil
    ) {
        let now = Date()
        self.id = UUID()
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
        self.watchProviders = watchProviders
        self.justWatchURLString = justWatchURL?.absoluteString
        self.imdbID = imdbID
        self.letterboxdURLString = letterboxdURL?.absoluteString
        self.userNotes = userNotes
        self.source = source
        self.streamingLocation = streamingLocation
        self.rating = rating
        self.statusRawValue = status.rawValue
        self.queuePosition = queuePosition
        self.dateAdded = dateAdded
        self.dateWatched = dateWatched
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Typed accessors

extension Movie {

    var status: MovieStatus {
        get { MovieStatus(rawValue: statusRawValue) ?? .queued }
        set { statusRawValue = newValue.rawValue }
    }

    var letterboxdURL: URL? {
        get { letterboxdURLString.flatMap(URL.init(string:)) }
        set { letterboxdURLString = newValue?.absoluteString }
    }

    var justWatchURL: URL? {
        get { justWatchURLString.flatMap(URL.init(string:)) }
        set { justWatchURLString = newValue?.absoluteString }
    }
}
