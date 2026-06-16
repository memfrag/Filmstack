//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting

struct MainRouting: Routing {

    // MARK: - Selectable

    /// Library sections that can be selected in the sidebar / tab bar.
    nonisolated enum Selectable: SelectableDestination {
        case queue
        case watched
        case maybeLater

        /// The movie status this section displays.
        var movieStatus: MovieStatus {
            switch self {
            case .queue: .queued
            case .watched: .watched
            case .maybeLater: .maybeLater
            }
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
