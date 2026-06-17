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

    var isActive: Bool { !genres.isEmpty || !sources.isEmpty }
    var activeCount: Int { genres.count + sources.count }

    func matches(_ movie: Movie) -> Bool {
        let genreOK = genres.isEmpty || !Set(movie.genres).isDisjoint(with: genres)
        let sourceOK = sources.isEmpty || (movie.source.map(sources.contains) ?? false)
        return genreOK && sourceOK
    }

    mutating func toggleGenre(_ genre: String) {
        if genres.contains(genre) { genres.remove(genre) } else { genres.insert(genre) }
    }

    mutating func toggleSource(_ source: String) {
        if sources.contains(source) { sources.remove(source) } else { sources.insert(source) }
    }

    mutating func clear() {
        genres.removeAll()
        sources.removeAll()
    }
}
