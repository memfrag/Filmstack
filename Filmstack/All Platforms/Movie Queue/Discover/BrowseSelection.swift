//
//  Filmstack
//

import Foundation

/// A movie selected from an external-browse list (Discover or Letterboxd) that
/// drives the shared detail pane. Carries optional Letterboxd watch context so the
/// detail can offer "Add as Watched".
struct BrowseSelection: Identifiable, Hashable {
    var result: MovieSearchResult
    /// Letterboxd watched date, when this came from the diary.
    var watchedDate: Date?
    /// Letterboxd member rating (out of 5), when present.
    var rating: Double?

    var id: Int { result.tmdbID }

    init(result: MovieSearchResult, watchedDate: Date? = nil, rating: Double? = nil) {
        self.result = result
        self.watchedDate = watchedDate
        self.rating = rating
    }
}
