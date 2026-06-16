//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SettingsUI
import AppRouting

struct InformationSection: View {

    @Environment(Router<MainRouting>.self) private var router

    var body: some View {
        Section {

            LabelSetting(
                "App Version",
                systemIcon: "app",
                info: AppVersion().description
            )

            PushSetting(
                "Attributions",
                systemIcon: "heart.text.square",
                value: MainRouting.Pushable.attributions
            )

        } header: {
            Text("Information")
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        InformationSection()
    }
    .appEnvironment(.mock())
}
