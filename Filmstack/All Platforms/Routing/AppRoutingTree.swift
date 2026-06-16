//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting

@MainActor var appRoutingTree: RoutingContextTree {
    RoutingContextTree {
        RoutingContext(MainRouting.self)
        /*MainRouting.self --> {
            TrailersRouting.self
            ShowtimesRouting.self
            SettingsRouting.self
        }*/
    }
}
