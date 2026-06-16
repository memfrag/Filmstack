//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppRouting

/// Top-level platform + size-class dispatcher.
///
/// - iPhone (always) and iPad in compact horizontal size class get a `TabView`
///   via `PhoneTabRoot`.
/// - iPad in regular width, Mac, and visionOS get a `NavigationSplitView` via
///   `SplitRoot`.
/// - Selection state is owned by the shared `Router<MainRouting>` and persists
///   across iPad compact↔regular transitions.
///
struct RootView: View {

    @Environment(Router<MainRouting>.self) private var router

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            PhoneTabRoot()
        } else {
            SplitRoot()
        }
        #else
        SplitRoot()
        #endif
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .appEnvironment(.mock())
}
