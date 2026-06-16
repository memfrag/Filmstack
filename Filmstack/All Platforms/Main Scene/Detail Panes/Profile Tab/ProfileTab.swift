//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import SettingsUI
import AppRouting

struct ProfileTab: View {

    @Environment(\.presentationNamespace) private var presentationNamespace
    @Environment(AppSettings.self) private var appSettings
    @Environment(EngineeringMode.self) private var engineeringMode
    @Environment(Router<MainRouting>.self) private var router

    // MARK: Body

    var body: some View {
        @Bindable var router = router
        @Bindable var appSettings = appSettings

        NavigationStack(path: $router[.profileTab]) {
            Form {
                InformationSection()

                Section {
                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }

                    #if DEBUG
                    NavigationLink {
                        EngineeringModeForm()
                            .navigationTitle("Engineering Mode")
                            .environment(engineeringMode)
                    } label: {
                        Label("Engineering", systemImage: "wrench.and.screwdriver.fill")
                    }
                    #endif
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                navigationBar
            }
            .pushableDestination(for: MainRouting.self) { destination in
                switch destination {
                case .attributions:
                    OpenSourceAttributions()
                }
            }
        }
    }

    // MARK: Navigation Bar

    @ToolbarContentBuilder var navigationBar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                router.presentSheet(.experiments)
            } label: {
                Image(systemName: "testtube.2")
            }
            #if os(iOS)
            .matchedTransitionSource(
                id: MainRouting.Presentable.experiments,
                in: presentationNamespace ?? .inert
            )
            #endif
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileTab()
        .appEnvironment(.mock())
}
