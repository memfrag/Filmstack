//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(macOS)

import AppKit

public extension NSImage {
    
    convenience init(requiredNamed name: String) {
        // swiftlint:disable:next force_unwrapping
        self.init(named: name)!
    }
}

#endif
