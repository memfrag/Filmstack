//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI
import AppDesign

// MARK: - SomeOnboardingScreen

struct SomeOnboardingScreen: View {

    private let onCompletion: () -> Void

    // MARK: Init

    init(onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
    }

    // MARK: Body

    var body: some View {
        Button("Complete Onboarding") {
            onCompletion()
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Preview

#Preview {
    SomeOnboardingScreen {
        // On completion
    }
}

#endif
