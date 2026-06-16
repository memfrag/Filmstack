//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppDesign
import AppRouting

/// `NavigationSplitView`-based root used on iPad (regular width), macOS, and visionOS.
///
/// Shares the `Router<MainRouting>.activeSelectable` selection state with
/// `PhoneTabRoot`, so the user's selected item persists across iPad compact↔regular
/// layout transitions.
///
struct SplitRoot: View {

    @Environment(Router<MainRouting>.self) private var router

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        @Bindable var router = router

        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $router.activeSelectable)
        } detail: {
            detail(for: router.activeSelectable)
        }
    }

    @ViewBuilder
    private func detail(for selectable: MainRouting.Selectable) -> some View {
        switch selectable {
        case .homeTab: HomeTab()
        case .exploreTab: ExploreTab()
        case .profileTab: ProfileTab()
        case .searchTab: SearchTab()
        }
    }
}

// MARK: - Preview

#Preview {
    SplitRoot()
        .appEnvironment(.mock())
}
