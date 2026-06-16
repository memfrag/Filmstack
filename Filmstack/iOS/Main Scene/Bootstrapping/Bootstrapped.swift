//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(iOS)

import SwiftUI

struct Bootstrapped<Content: View>: View {
    
    private let content: () -> Content
    private let task: () async -> Void
    
    @State private var bootstrapper = Bootstrapper()

    init(@ViewBuilder _ content: @escaping () -> Content, task: @escaping () async -> Void) {
        self.content = content
        self.task = task
    }
    
    var body: some View {
        ZStack {
            content()
                .zIndex(0)
            if bootstrapper.isBootstrapping {
                BootstrapView()
                    .zIndex(1)
            }
        }
        .task {
            print("Running bootstrapper task!")
            await bootstrapper.bootstrap(task)
        }
    }
}

// MARK: - Preview

#Preview {
    Bootstrapped {
        Text("Hello, World!")
    } task: {
        
    }
}

#endif
