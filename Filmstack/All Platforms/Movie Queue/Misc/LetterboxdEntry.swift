//
//  Filmstack
//

import Foundation

/// A watched-film entry parsed from a Letterboxd diary RSS feed.
struct LetterboxdEntry: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var tmdbID: Int?
    var title: String
    var year: Int?
    var watchedDate: Date?
    /// Member rating out of 5, if present.
    var rating: Double?
    var rewatch: Bool
    var posterURL: URL?
    var link: URL?

    var watchedDateText: String? {
        watchedDate?.formatted(date: .abbreviated, time: .omitted)
    }

    /// Maps to a transient search result so the existing detail view can show it.
    var asSearchResult: MovieSearchResult? {
        guard let tmdbID else { return nil }
        return MovieSearchResult(tmdbID: tmdbID, title: title, releaseYear: year)
    }
}
