//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI
import AppDesign

/// There also needs to be a `SplashScreen.storyboard` that matches this layout.
struct SplashScreen: View {
    
    var body: some View {
        Color("LaunchBackground")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}

#Preview {
    SplashScreen()
}

#endif
