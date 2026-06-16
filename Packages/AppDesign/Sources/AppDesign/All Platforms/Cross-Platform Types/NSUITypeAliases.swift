//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(macOS)

import AppKit

public typealias NSUIColor = NSColor
public typealias NSUIImage = NSImage

#else

import UIKit

public typealias NSUIColor = UIColor
public typealias NSUIImage = UIImage

#endif
