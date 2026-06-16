//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI

/// Update this when the onboarding changes and needs to be seen again.
fileprivate let currentOnboardingID = "Onboarding.hasSeenOnBoardingV1"

@Observable class OnboardingModel {

    enum State {
        case onboarding
        case content
    }

    private(set) var state: State
    
    private static var hasSeenOnBoarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: currentOnboardingID)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: currentOnboardingID)
        }
    }
    
    init() {
        if Self.hasSeenOnBoarding {
            state = .content
        } else {
            state = .onboarding
        }
    }
    
    func completeOnboarding() {
        Self.hasSeenOnBoarding = true
        state = .content
    }
}

#endif
