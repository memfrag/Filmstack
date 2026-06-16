//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// Sidebar list backing `SplitRoot`'s NavigationSplitView leading column.
///
/// Selection drives the detail column via the shared
/// `Router<MainRouting>.activeSelectable` binding.
///
struct Sidebar: View {

    @Binding var selection: MainRouting.Selectable

    private let items: [(MainRouting.Selectable, String, String)] = [
        (.homeTab, "Home", "house.fill"),
        (.exploreTab, "Explore", "binoculars.fill"),
        (.profileTab, "Profile", "person.fill"),
        (.searchTab, "Search", "magnifyingglass")
    ]

    var body: some View {
        List(selection: Binding(
            get: { Optional(selection) },
            set: { if let new = $0 { selection = new } }
        )) {
            ForEach(items, id: \.0) { item in
                NavigationLink(value: item.0) {
                    Label(item.1, systemImage: item.2)
                }
            }
        }
        .navigationTitle(Bundle.main.appName)
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        #endif
    }
}

private extension Bundle {
    var appName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
    }
}

// MARK: - Preview

#Preview {
    NavigationSplitView {
        Sidebar(selection: .constant(.homeTab))
    } detail: {
        Text("Detail")
    }
}
