//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI

@MainActor @Observable class Bootstrapper {
    
    private(set) var isBootstrapping: Bool = true
    
    func bootstrap(_ task: @escaping () async -> Void) async {
        await task()
        await MainActor.run {
            withAnimation {
                isBootstrapping = false
            }
        }
    }
}

#endif
