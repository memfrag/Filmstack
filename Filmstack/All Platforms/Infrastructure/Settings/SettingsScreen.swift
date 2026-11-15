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
                NavigationLink {
                    TMDBKeySettings()
                } label: {
                    Label("TMDB API Key", systemImage: "key.fill")
                }
                .filmSettingsRow()
                LabeledContent {
                    TextField("Username", text: $appSettings.letterboxdUsername)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } label: {
                    Label("Letterboxd", systemImage: "person.crop.square")
                }
            } header: {
                Text("Accounts")
            } footer: {
                Text("Your Letterboxd username shows the films from your public diary in Browse.")
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
                Toggle("Release Day Reminders", isOn: $appSettings.releaseNotifications)
            } header: {
                Text("Notifications")
            } footer: {
                Text("A notification at 8:00 on the day a movie in your library comes out.")
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
        }
        #if os(iOS)
        .navigationTitle("Profile")
        #else
        .navigationTitle("Settings")
        #endif
        .formStyle(.grouped)
        .filmSettingsForm()
    }
}

extension View {

    /// On iOS, puts a settings form on the app's dark base colour instead of
    /// the system grouped background, with an inline (small) title. A no-op
    /// on macOS (Settings window).
    func filmSettingsForm() -> some View {
        #if os(iOS)
        scrollContentBackground(.hidden)
            .background(Palette.base.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// On iOS, gives a settings form section rows that match the app's cards
    /// instead of the system's opaque grey ones, and hides the system
    /// separators (rows draw their own; see `filmSettingsRow(separated:)`).
    /// A no-op on macOS.
    func filmSettingsRows() -> some View {
        #if os(iOS)
        listRowBackground(SettingsRowBackground(separated: false))
            .listRowSeparator(.hidden)
        #else
        self
        #endif
    }

    /// On iOS, draws a faint separator under this row that spans the row's
    /// background edge to edge. Use on every row but the last in a section.
    /// A no-op on macOS.
    func filmSettingsRow(separated: Bool = true) -> some View {
        #if os(iOS)
        listRowBackground(SettingsRowBackground(separated: separated))
        #else
        self
        #endif
    }
}

#if os(iOS)
/// A settings row's fill, optionally with a hairline along its bottom edge.
private struct SettingsRowBackground: View {
    let separated: Bool

    var body: some View {
        Palette.elevated.opacity(0.75)
            .overlay(alignment: .bottom) {
                if separated {
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 1)
                }
            }
    }
}
#endif

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SettingsScreen()
            .appEnvironment(.mock())
    }
}
#endif
