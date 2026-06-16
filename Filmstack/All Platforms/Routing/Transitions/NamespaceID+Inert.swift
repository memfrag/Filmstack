//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

extension Namespace.ID {

    /// Use as a fallback default value in places where namespace is optional.
    ///
    /// Example:
    /// ```
    /// @Environment(\.presentationNamespace) var presentationNamespace
    ///
    /// .matchedTransitionSource(
    ///     id: "SomeID",
    ///     in: presentationNamespace ?? .inert
    /// )
    /// ```
    static var inert: Namespace.ID {
        Namespace().wrappedValue
    }
}
