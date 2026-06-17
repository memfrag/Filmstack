//
//  Filmstack
//

import Foundation

/// An optional filter applied on top of the selected library section.
enum LibraryFilter: Hashable {
    case all
    case genre(String)
    case source(String)

    /// Whether a movie passes this filter.
    func matches(_ movie: Movie) -> Bool {
        switch self {
        case .all: true
        case .genre(let genre): movie.genres.contains(genre)
        case .source(let source): movie.source == source
        }
    }

    var isActive: Bool {
        if case .all = self { return false }
        return true
    }
}
