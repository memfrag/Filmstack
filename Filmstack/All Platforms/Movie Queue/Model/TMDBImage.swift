//
//  Filmstack
//

import Foundation

/// The contexts a poster is displayed in, mapped to a TMDB image size.
enum PosterSize {
    case thumbnail
    case queue
    case detail

    /// TMDB image path component, e.g. "w185".
    ///
    /// TMDB serves a fixed set of poster widths; these are picked to comfortably
    /// cover each display context on Retina without over-fetching.
    var tmdbPath: String {
        switch self {
        case .thumbnail: "w154"
        case .queue: "w185"
        case .detail: "w500"
        }
    }
}

/// Builds TMDB image URLs.
///
/// Poster artwork is served publicly from TMDB's image CDN and does not require an
/// API token, so these URLs can be loaded directly.
enum TMDBImage {

    /// Base URL of the TMDB image CDN.
    static let baseURLString = "https://image.tmdb.org/t/p/"

    /// Builds a poster URL for the given `posterPath` (e.g. "/abc123.jpg").
    ///
    /// Returns `nil` when there is no poster path, so callers can fall back to a
    /// placeholder.
    static func posterURL(path: String?, size: PosterSize) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(baseURLString)\(size.tmdbPath)\(normalized)")
    }

    /// Builds a wide backdrop URL (used for the detail hero image).
    static func backdropURL(path: String?, width: String = "w1280") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(baseURLString)\(width)\(normalized)")
    }

    /// Builds a provider logo URL (watch providers).
    static func logoURL(path: String?, width: String = "w92") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(baseURLString)\(width)\(normalized)")
    }
}
