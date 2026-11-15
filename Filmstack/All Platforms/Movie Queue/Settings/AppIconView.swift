//
//  Filmstack
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The app's own icon, as the system renders it, for the About page.
///
/// The icon is an Icon Composer file (`DefaultAppIcon.icon`), so there's no
/// plain image asset to reference; this loads what the build put in the
/// bundle instead. Falls back to an SF Symbol if nothing can be loaded.
struct AppIconView: View {

    var size: CGFloat = 88

    var body: some View {
        Group {
            if let image = Self.iconImage {
                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.elevated)
            }
        }
        .frame(width: size, height: size)
        #if os(iOS)
        // iOS bundles the icon unmasked; macOS's icon already has its shape.
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        #endif
        .accessibilityHidden(true)
    }

    private static let iconImage: Image? = {
        #if os(iOS)
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        // The full-size icon by its asset name, then the largest bundled file.
        let names = [primary?["CFBundleIconName"] as? String].compactMap { $0 }
            + ((primary?["CFBundleIconFiles"] as? [String]) ?? []).reversed()
        for name in names {
            if let image = UIImage(named: name) {
                return Image(uiImage: image)
            }
        }
        return nil
        #else
        return Image(nsImage: NSApplication.shared.applicationIconImage)
        #endif
    }()
}
