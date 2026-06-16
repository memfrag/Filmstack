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
            Section("Appearance") {
                Picker("Color Scheme", selection: $appSettings.colorScheme) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
    }
}

private extension AppColorScheme {
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsScreen()
            .appEnvironment(.mock())
    }
}
