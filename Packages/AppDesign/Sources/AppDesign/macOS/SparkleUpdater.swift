//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(macOS)

import SwiftUI
import Sparkle

/// A re-export of `SPUStandardUpdaterController` so apps can wire up Sparkle
/// without depending on Sparkle directly at the app target level.
public typealias SparkleUpdaterController = SPUStandardUpdaterController
public typealias SparkleUpdater = SPUUpdater

#endif
