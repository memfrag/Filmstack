//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting

extension AppEnvironment {

    // MARK: - Live AppEnvironment

    /// Builds a live environment configured for production behavior.
    ///
    /// Intended only for ``#Preview`` usage and tests where an explicit instance is required.
    /// Most code should access ``shared`` instead.
    ///
    /// - Returns: A new ``AppEnvironment`` instance with live dependencies.
    ///
    internal static func live() -> AppEnvironment {
        let apiKeyStore = KeychainAPIKeyStore()
        return AppEnvironment(
            metaRouter: MetaRouter(tree: appRoutingTree),
            appSettings: AppSettings(),
            apiKeyStore: apiKeyStore,
            movieAPIClient: TMDBClient(keyStore: apiKeyStore),
            authService: AuthService.mock(),
            engineeringMode: EngineeringMode.shared
        )
    }
}
