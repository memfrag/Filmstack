//
//  Filmstack
//

import Foundation

/// A multi-select filter applied on top of the selected library section.
///
/// Within a category (genres, sources) selections are OR'd; across categories
/// they are AND'd. An empty category imposes no constraint.
struct LibraryFilter: Equatable {
    var genres: Set<String> = []
    var sources: Set<String> = []
    var locations: Set<String> = []
    /// `Mood` raw values.
    var moods: Set<String> = []
    /// Set by plain-language search ("under two hours").
    var maxRuntimeMinutes: Int?
    /// Set by plain-language search ("from the nineties").
    var minYear: Int?
    var maxYear: Int?

    var isActive: Bool { activeCount > 0 }
    var activeCount: Int {
        genres.count + sources.count + locations.count + moods.count
            + (maxRuntimeMinutes == nil ? 0 : 1)
            + (minYear == nil && maxYear == nil ? 0 : 1)
    }

    func matches(_ movie: Movie) -> Bool {
        let genreOK = genres.isEmpty || !Set(movie.genres).isDisjoint(with: genres)
        let sourceOK = sources.isEmpty || (movie.source.map(sources.contains) ?? false)
        let locationOK = locations.isEmpty || (movie.streamingLocation.map(locations.contains) ?? false)
        let moodOK = moods.isEmpty || !Set(movie.moodTags).isDisjoint(with: moods)
        let runtimeOK = maxRuntimeMinutes.map { max in (movie.runtimeMinutes ?? 0) <= max } ?? true
        let year = movie.releaseYear ?? 0
        let yearOK = (minYear.map { year >= $0 } ?? true) && (maxYear.map { year <= $0 } ?? true)
        return genreOK && sourceOK && locationOK && moodOK && runtimeOK && yearOK
    }

    /// A short label for the year range, e.g. "1990–1999" or "From 2010".
    var yearRangeLabel: String? {
        switch (minYear, maxYear) {
        case let (min?, max?): min == max ? String(min) : "\(min)–\(max)"
        case let (min?, nil): String(localized: "From \(String(min))")
        case let (nil, max?): String(localized: "Until \(String(max))")
        case (nil, nil): nil
        }
    }

    mutating func toggleMood(_ mood: String) {
        if moods.contains(mood) { moods.remove(mood) } else { moods.insert(mood) }
    }

    mutating func toggleGenre(_ genre: String) {
        if genres.contains(genre) { genres.remove(genre) } else { genres.insert(genre) }
    }

    mutating func toggleSource(_ source: String) {
        if sources.contains(source) { sources.remove(source) } else { sources.insert(source) }
    }

    mutating func toggleLocation(_ location: String) {
        if locations.contains(location) { locations.remove(location) } else { locations.insert(location) }
    }

    mutating func clear() {
        genres.removeAll()
        sources.removeAll()
        locations.removeAll()
        moods.removeAll()
        maxRuntimeMinutes = nil
        minYear = nil
        maxYear = nil
    }
}
