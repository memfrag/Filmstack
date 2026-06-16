//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI

struct Onboarded<Content: View>: View {

    @State private var model = OnboardingModel()

    private let content: () -> Content

    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        contentSelector
    }

    @ViewBuilder private var contentSelector: some View {
        switch model.state {
        case .onboarding: onboarding
        case .content: content()
        }
    }

    @ViewBuilder private var onboarding: some View {
        SomeOnboardingScreen {
            model.completeOnboarding()
        }
    }
}

// MARK: - Preview

#Preview {
    Onboarded {
        Text("Onboarded!")
    }
}

#endif
