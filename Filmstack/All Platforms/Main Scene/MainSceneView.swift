//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppRouting

/// The top-level view inside the main `WindowGroup`.
///
/// On iOS, this view layers the bootstrapping splash and onboarding flow over the
/// platform dispatcher (`RootView`). On macOS and visionOS, it skips straight to
/// `RootView` — those platforms don't ship splash/onboarding by default.
///
struct MainSceneView: View {

    @Environment(AuthService.self) private var authService

    @Namespace private var presentationMainNamespace

    var body: some View {
        #if os(iOS)
        Bootstrapped {
            Onboarded {
                rootContent
            }
        } task: {
            await refreshAuth()
        }
        #else
        rootContent
            .task { await refreshAuth() }
        #endif
    }

    @ViewBuilder private var rootContent: some View {
        RootView()
            .presentableDestination(for: MainRouting.self) { destination in
                presentable(destination)
            }
            .environment(\.presentationNamespace, presentationMainNamespace)
    }

    // MARK: Navigation

    @ViewBuilder private func presentable(_ destination: MainRouting.Presentable) -> some View {
        switch destination {
        case .experiments:
            #if os(iOS)
            Text("Experiments")
                .navigationTransition(.zoom(sourceID: destination, in: presentationMainNamespace))
            #else
            Text("Experiments")
            #endif
        case .whatsNew:
            Text("What's New")
        }
    }

    // MARK: Auth

    private func refreshAuth() async {
        do {
            try await authService.refreshTokenStatus()
        } catch {
            dump(error)
        }
    }
}

// MARK: - Preview

#Preview {
    MainSceneView()
        .appEnvironment(.mock())
}
