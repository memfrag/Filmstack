//
//  Filmstack
//

import Foundation

/// Builds an "Open in Letterboxd" URL for a movie.
///
/// Resolution order (per spec):
/// 1. An explicit `letterboxdURL` saved on the movie.
/// 2. A TMDB-ID search URL when the movie came from TMDB.
/// 3. A title search URL for manual entries.
///
/// The MVP intentionally opens a Letterboxd *search* rather than scraping for the
/// exact film page, so the action is labelled "Open in Letterboxd".
func letterboxdURL(for movie: Movie) -> URL? {
    if let url = movie.letterboxdURL {
        return url
    }

    if let tmdbID = movie.tmdbID {
        return URL(string: "https://letterboxd.com/search/tmdb:\(tmdbID)/")
    }

    let allowed = CharacterSet.urlPathAllowed
    let query = movie.title.addingPercentEncoding(withAllowedCharacters: allowed) ?? movie.title
    return URL(string: "https://letterboxd.com/search/\(query)/")
}
