//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppDesign
#if os(macOS)
import Sparkle
#endif

@main
struct FilmstackApp: App {

    #if os(iOS)
    // swiftlint:disable:next weak_delegate
    @UIApplicationDelegateAdaptor(iOSAppDelegate.self) var appDelegate
    #elseif os(visionOS)
    // swiftlint:disable:next weak_delegate
    @UIApplicationDelegateAdaptor(visionOSAppDelegate.self) var appDelegate
    #elseif os(macOS)
    // swiftlint:disable:next weak_delegate
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate

        private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
        #endif

    init() {
        AppDesign.apply()
    }

    var body: some Scene {
        WindowGroup {
            MainSceneView()
                .appEnvironment(.default)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .terminatesAppWhenClosed()
                #endif
        }
        .modelContainer(MovieStore.makeContainer())
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
                        CheckForUpdatesCommand(updater: updaterController.updater)
                        HelpCommands()
            MyCommands()
        }
        #elseif os(visionOS)
        .defaultSize(width: 1280, height: 720)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        MenuBarWindow()
        SettingsWindow()
        HelpWindow()
        #endif
    }
}
