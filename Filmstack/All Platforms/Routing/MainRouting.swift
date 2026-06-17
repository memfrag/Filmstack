//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting

struct MainRouting: Routing {

    // MARK: - Selectable

    /// Library sections that can be selected in the sidebar / tab bar.
    nonisolated enum Selectable: SelectableDestination, CaseIterable {
        case queue
        case upcoming
        case watched
        case maybeLater

        var title: String {
            switch self {
            case .queue: "Queue"
            case .upcoming: "Upcoming"
            case .watched: "Watched"
            case .maybeLater: "Maybe Later"
            }
        }

        var systemImage: String {
            switch self {
            case .queue: "house"
            case .upcoming: "calendar.badge.clock"
            case .watched: "checkmark.circle"
            case .maybeLater: "clock"
            }
        }

        /// The movie status this section maps to, or `nil` for derived sections
        /// like Upcoming that span statuses.
        var status: MovieStatus? {
            switch self {
            case .queue: .queued
            case .watched: .watched
            case .maybeLater: .maybeLater
            case .upcoming: nil
            }
        }

        /// The status a newly added movie gets in this section, or `nil` if the
        /// section doesn't support adding.
        var defaultAddStatus: MovieStatus? {
            switch self {
            case .queue, .upcoming: .queued
            case .maybeLater: .maybeLater
            case .watched: nil
            }
        }

        /// Whether rows show a queue position number.
        var showsPosition: Bool { self == .queue }
    }

    // MARK: - Pushable

    /// Views that can be pushed.
    nonisolated enum Pushable: PushableDestination {

        // MARK: Profile tab
        case attributions
    }

    // MARK: - Presentable

    /// Views that can be presented, i.e. sheets and other modals.
    nonisolated enum Presentable: PresentableDestination {
        case experiments

        // MARK: Profile tab
        case whatsNew
    }
}
