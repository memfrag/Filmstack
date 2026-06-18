//
//  Filmstack
//

import Foundation

/// A streaming provider a movie is available on, from TMDB's watch/providers
/// endpoint (data powered by JustWatch).
struct WatchProvider: Codable, Hashable, Sendable {
    var name: String
    var logoPath: String?
}

/// Resolved streaming availability for a region: providers plus the JustWatch link.
struct WatchAvailability: Sendable {
    var providers: [WatchProvider]
    var link: URL?
}
