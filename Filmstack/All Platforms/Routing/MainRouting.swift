//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting

struct MainRouting: Routing {

    // MARK: - Selectable

    /// Views that can be selected, i.e. tabs.
    nonisolated enum Selectable: SelectableDestination {
        case homeTab
        case exploreTab
        case profileTab
        case searchTab
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
