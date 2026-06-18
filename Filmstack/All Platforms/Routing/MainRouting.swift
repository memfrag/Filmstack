//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting

struct MainRouting: Routing {

    // MARK: - Selectable

    /// Sections that can be selected in the sidebar / tab bar.
    nonisolated enum Selectable: SelectableDestination {
        case queue
        case upcoming
        case watched
        case maybeLater
        case discover(DiscoverList)

        /// Library sections.
        static let libraryCases: [Selectable] = [.queue, .upcoming, .watched, .maybeLater]
        /// Discover sections.
        static let discoverCases: [Selectable] = DiscoverList.allCases.map { .discover($0) }

        static var allCases: [Selectable] { libraryCases + discoverCases }

        var title: String {
            switch self {
            case .queue: "Queue"
            case .upcoming: "Upcoming"
            case .watched: "Watched"
            case .maybeLater: "Maybe Later"
            case .discover(let list): list.title
            }
        }

        var systemImage: String {
            switch self {
            case .queue: "house"
            case .upcoming: "calendar.badge.clock"
            case .watched: "checkmark.circle"
            case .maybeLater: "clock"
            case .discover(let list): list.systemImage
            }
        }

        /// The movie status this section maps to, or `nil` for sections that
        /// don't map to a single status (Upcoming, Discover).
        var status: MovieStatus? {
            switch self {
            case .queue: .queued
            case .watched: .watched
            case .maybeLater: .maybeLater
            case .upcoming, .discover: nil
            }
        }

        /// The status a newly added movie gets in this section, or `nil` if the
        /// section doesn't support adding directly.
        var defaultAddStatus: MovieStatus? {
            switch self {
            case .queue, .upcoming: .queued
            case .maybeLater: .maybeLater
            case .watched, .discover: nil
            }
        }

        /// Whether rows show a queue position number.
        var showsPosition: Bool { self == .queue }

        /// The Discover list this section represents, if any.
        var discoverList: DiscoverList? {
            if case .discover(let list) = self { return list }
            return nil
        }
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
