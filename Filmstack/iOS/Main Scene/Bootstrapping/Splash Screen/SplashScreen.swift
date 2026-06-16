//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI
import AppDesign

/// There also needs to be a `SplashScreen.storyboard` that matches this layout.
struct SplashScreen: View {
    
    var body: some View {
        VStack {
            Text("Splash Screen")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green)
        .ignoresSafeArea()
    }
}

#Preview {
    SplashScreen()
}

#endif
