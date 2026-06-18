//
//  Filmstack
//

import Foundation

/// A provider a movie is available on, from TMDB's watch/providers endpoint
/// (data powered by JustWatch).
struct WatchProvider: Codable, Hashable, Sendable {

    /// How the movie is available from this provider.
    enum Access: String, Codable, Sendable, CaseIterable {
        case stream
        case rent
        case buy

        var title: String {
            switch self {
            case .stream: "Stream"
            case .rent: "Rent"
            case .buy: "Buy"
            }
        }
    }

    var name: String
    var logoPath: String?
    var access: Access

    init(name: String, logoPath: String? = nil, access: Access = .stream) {
        self.name = name
        self.logoPath = logoPath
        self.access = access
    }

    // Defaults `access` to `.stream` so previously stored providers (encoded
    // before `access` existed) still decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        logoPath = try container.decodeIfPresent(String.self, forKey: .logoPath)
        access = try container.decodeIfPresent(Access.self, forKey: .access) ?? .stream
    }
}

/// Resolved streaming availability for a region: providers plus the JustWatch link.
struct WatchAvailability: Sendable {
    var providers: [WatchProvider]
    var link: URL?
}
