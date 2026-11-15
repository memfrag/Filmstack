//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// Cross-platform settings UI. Hosted by:
/// - macOS: the `Settings` scene (`SettingsWindow`), reachable from the sidebar.
/// - iPhone / iPad / visionOS: pushed onto a navigation stack.
///
struct SettingsScreen: View {

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings

        Form {
            Section {
                NavigationLink {
                    AboutScreen()
                } label: {
                    Label("About Filmstack", systemImage: "info.circle")
                }
            }
            .filmSettingsRows()

            Section {
                Toggle("Show Maybe Later", isOn: $appSettings.showsMaybeLater)
            } header: {
                Text("Library")
            } footer: {
                Text("A separate list for movies you're not sure about yet.")
            }
            .filmSettingsRows()

            Section {
                Toggle("Depth of Field Blur", isOn: $appSettings.pickerDepthOfField)
            } header: {
                Text("Movie Picker")
            } footer: {
                Text("Softens cases away from the one in focus, like a camera lens. Scrolling may be less smooth on slower devices.")
            }
            .filmSettingsRows()

            Section("Movie Database") {
                NavigationLink {
                    TMDBKeySettings()
                } label: {
                    Label("TMDB API Key", systemImage: "film")
                }
            }
            .filmSettingsRows()
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
        .filmSettingsForm()
    }
}

extension View {

    /// On iOS, puts a settings form on the app's purple wash instead of the
    /// system grouped background. A no-op on macOS (Settings window).
    func filmSettingsForm() -> some View {
        #if os(iOS)
        scrollContentBackground(.hidden)
            .filmWindowBackground()
        #else
        self
        #endif
    }

    /// On iOS, gives a settings form section glassy rows that match the app's
    /// cards, instead of the system's opaque grey ones. A no-op on macOS.
    func filmSettingsRows() -> some View {
        #if os(iOS)
        listRowBackground(Palette.elevated.opacity(0.75))
        #else
        self
        #endif
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SettingsScreen()
            .appEnvironment(.mock())
    }
}
#endif
