//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

#if os(macOS)

import SwiftUI

struct HelpCommands: Commands {
    
    @Environment(\.openWindow) private var openWindow
            
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button {
                openWindow(id: HelpWindow.windowID)
            } label: {
                Text("\(Bundle.main.name) Help")
            }
        }
    }
}

#endif
