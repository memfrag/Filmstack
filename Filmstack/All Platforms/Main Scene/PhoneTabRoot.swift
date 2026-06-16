//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI
import AppDesign
import AppRouting

/// `TabView`-based root used on iPhone and on iPad in compact horizontal size class.
struct PhoneTabRoot: View {

    @State private var searchTerm: String = ""

    @Environment(Router<MainRouting>.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.activeSelectable) {
            Tab("Home", systemImage: "house.fill", value: .homeTab) {
                HomeTab()
            }
            Tab("Explore", systemImage: "binoculars.fill", value: .exploreTab) {
                ExploreTab()
            }
            Tab("Profile", systemImage: "person.fill", value: .profileTab) {
                ProfileTab()
            }
            Tab("Search", systemImage: "magnifyingglass", value: .searchTab, role: .search) {
                SearchTab()
            }
        }
        .searchable(text: $searchTerm)
    }
}

// MARK: - Preview

#Preview {
    PhoneTabRoot()
        .appEnvironment(.mock())
}

#endif
