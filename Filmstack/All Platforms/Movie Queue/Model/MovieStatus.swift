//
//  Filmstack
//

import Foundation

/// Where a movie currently sits in the user's library.
enum MovieStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case watched
    case maybeLater

    var title: String {
        switch self {
        case .queued: "Queue"
        case .watched: "Watched"
        case .maybeLater: "Maybe Later"
        }
    }

    var systemImage: String {
        switch self {
        case .queued: "house"
        case .watched: "checkmark.circle"
        case .maybeLater: "clock"
        }
    }
}
