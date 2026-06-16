//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI

struct BootstrapView: View {

    var body: some View {
        VStack {
            SplashScreen()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .background(Color.white)
    }
}

// MARK: - Preview

#Preview {
    BootstrapView()
}

#endif
