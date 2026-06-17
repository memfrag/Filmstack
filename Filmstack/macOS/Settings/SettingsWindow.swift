//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(macOS)

import SwiftUI

/// Show settings window by using a SettingsLink SwiftUI view.
struct SettingsWindow: Scene {

    private enum Tabs: Hashable {
        case general
        case movieDatabase
        case about
    }

    var body: some Scene {
        Settings {
            tabs
        }
    }

    @ViewBuilder var tabs: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
                .frame(width: 375, height: 150)

            TMDBKeySettings()
                .tabItem {
                    Label("Movie Database", systemImage: "film")
                }
                .tag(Tabs.movieDatabase)
                .frame(width: 460, height: 380)

            AboutScreen()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tabs.about)
                .frame(width: 460, height: 560)
        }
    }
}

#endif
