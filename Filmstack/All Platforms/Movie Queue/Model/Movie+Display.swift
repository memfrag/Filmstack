//
//  Filmstack
//

import Foundation

/// Presentation helpers for `Movie`. Kept separate from the persisted model.
extension Movie {

    /// e.g. "2024". Falls back to the release date's year when `releaseYear` is unset.
    var yearText: String? {
        if let releaseYear { return String(releaseYear) }
        guard let releaseDate else { return nil }
        return String(Calendar.current.component(.year, from: releaseDate))
    }

    /// e.g. "2h 46m" or "1h 38m".
    var runtimeText: String? {
        guard let minutes = runtimeMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }

    /// e.g. "Sci-Fi, Adventure".
    var genresText: String? {
        genres.isEmpty ? nil : genres.joined(separator: ", ")
    }

    /// Compact metadata line for rows, e.g. "2024 · 2h 46m · Sci-Fi, Adventure".
    var metadataLine: String {
        [yearText, runtimeText, genresText]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// e.g. "May 23, 2024".
    var dateAddedText: String {
        dateAdded.formatted(date: .abbreviated, time: .omitted)
    }

    var dateWatchedText: String? {
        dateWatched?.formatted(date: .abbreviated, time: .omitted)
    }

    var releaseDateText: String? {
        releaseDate?.formatted(date: .long, time: .omitted)
    }

    /// Whether the movie's release date is in the future.
    var isUpcoming: Bool {
        guard let releaseDate else { return false }
        return releaseDate > Date()
    }
}
