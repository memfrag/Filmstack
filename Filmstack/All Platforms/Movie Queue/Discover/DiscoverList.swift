//
//  Filmstack
//

import Foundation

/// A TMDB movie list shown in the Discover section.
nonisolated enum DiscoverList: String, Codable, Hashable, Sendable, CaseIterable {
    case nowPlaying
    case popular
    case topRated
    case upcoming

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .popular: "Popular"
        case .topRated: "Top Rated"
        case .upcoming: "Upcoming"
        }
    }

    var systemImage: String {
        switch self {
        case .nowPlaying: "play.circle"
        case .popular: "flame"
        case .topRated: "star"
        case .upcoming: "calendar"
        }
    }

    /// TMDB endpoint path.
    var path: String {
        switch self {
        case .nowPlaying: "movie/now_playing"
        case .popular: "movie/popular"
        case .topRated: "movie/top_rated"
        case .upcoming: "movie/upcoming"
        }
    }

    /// Whether a region parameter is meaningful (release-window lists).
    var usesRegion: Bool { self == .nowPlaying || self == .upcoming }
}
