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
        case letterboxd
        /// The Profile tab with the app's settings (a tab on iPhone, a sidebar
        /// row on iPad; macOS uses its Settings window instead).
        case profile

        /// Library sections.
        static let libraryCases: [Selectable] = [.queue, .upcoming, .watched, .maybeLater]
        /// Library sections to show, leaving out Maybe Later unless enabled.
        static func visibleLibraryCases(showingMaybeLater: Bool) -> [Selectable] {
            showingMaybeLater ? libraryCases : libraryCases.filter { $0 != .maybeLater }
        }
        /// Discover sections.
        static let discoverCases: [Selectable] = DiscoverList.allCases.map { .discover($0) }
        /// Miscellaneous sections.
        static let miscCases: [Selectable] = [.letterboxd]

        static var allCases: [Selectable] { libraryCases + discoverCases + miscCases + [.profile] }

        var title: String {
            switch self {
            case .queue: "Queue"
            case .upcoming: "Upcoming"
            case .watched: "Watched"
            case .maybeLater: "Maybe Later"
            case .discover(let list): list.title
            case .letterboxd: "Letterboxd"
            case .profile: "Profile"
            }
        }

        var systemImage: String {
            switch self {
            case .queue: "house"
            case .upcoming: "calendar.badge.clock"
            case .watched: "checkmark.circle"
            case .maybeLater: "clock"
            case .discover(let list): list.systemImage
            case .letterboxd: "film.stack"
            case .profile: "person.crop.circle"
            }
        }

        /// The movie status this section maps to, or `nil` for sections that
        /// don't map to a single status (Upcoming, Discover, Letterboxd).
        var status: MovieStatus? {
            switch self {
            case .queue: .queued
            case .watched: .watched
            case .maybeLater: .maybeLater
            case .upcoming, .discover, .letterboxd, .profile: nil
            }
        }

        /// The status a newly added movie gets in this section, or `nil` if the
        /// section doesn't support adding directly.
        var defaultAddStatus: MovieStatus? {
            switch self {
            case .queue, .upcoming: .queued
            case .maybeLater: .maybeLater
            case .watched, .discover, .letterboxd, .profile: nil
            }
        }

        /// Whether rows show a queue position number.
        var showsPosition: Bool { self == .queue }

        /// The Discover list this section represents, if any.
        var discoverList: DiscoverList? {
            if case .discover(let list) = self { return list }
            return nil
        }

        /// Whether this section browses external movies (Discover, Letterboxd)
        /// that drive the shared `DiscoverDetailColumn`.
        var isExternalBrowse: Bool {
            if case .discover = self { return true }
            return self == .letterboxd
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
