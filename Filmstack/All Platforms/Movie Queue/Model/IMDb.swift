//
//  Filmstack
//

import Foundation

/// Builds an "Open in IMDb" URL for a movie.
///
/// Resolution order:
/// 1. A direct title page when the IMDb ID is known (from TMDB's `imdb_id`).
/// 2. An IMDb title search for the movie's name otherwise.
func imdbURL(for movie: Movie) -> URL? {
    if let imdbID = movie.imdbID, !imdbID.isEmpty {
        return URL(string: "https://www.imdb.com/title/\(imdbID)/")
    }

    let allowed = CharacterSet.urlQueryAllowed
    let query = movie.title.addingPercentEncoding(withAllowedCharacters: allowed) ?? movie.title
    return URL(string: "https://www.imdb.com/find/?q=\(query)&s=tt")
}
