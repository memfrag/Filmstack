//
//  Filmstack
//

import SwiftUI

/// Core color palette for the cinematic dark-purple visual system.
enum Palette {
    /// Near-black with a slight purple tint — the app's base surface.
    static let base = Color(red: 0.055, green: 0.047, blue: 0.090)
    /// Slightly raised surface.
    static let elevated = Color(red: 0.098, green: 0.082, blue: 0.145)
    /// Darker glassy sidebar panel.
    static let sidebar = Color(red: 0.043, green: 0.035, blue: 0.075)

    /// Subtle card fill over the base.
    static let card = Color.white.opacity(0.045)

    /// Violet accent.
    static let accent = Color(red: 0.60, green: 0.42, blue: 0.98)
    static let accentBright = Color(red: 0.73, green: 0.57, blue: 1.0)

    static let textPrimary = Color(white: 0.97)
    static let textSecondary = Color(red: 0.72, green: 0.70, blue: 0.82)

    static let separator = Color.white.opacity(0.10)
    static let hairline = Color.white.opacity(0.06)
}

/// Reusable gradients.
enum Gradients {

    /// Window-wide background wash.
    static let window = LinearGradient(
        colors: [Color(red: 0.105, green: 0.072, blue: 0.165), Color(red: 0.035, green: 0.028, blue: 0.055)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Deep purple gradient for a selected row.
    static let selectedRow = LinearGradient(
        colors: [Palette.accent.opacity(0.90), Palette.accent.opacity(0.45)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Primary accent button fill.
    static let accentButton = LinearGradient(
        colors: [Palette.accentBright, Palette.accent],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Hero backdrop fallback when no artwork is available.
    static let hero = LinearGradient(
        colors: [Color(red: 0.28, green: 0.18, blue: 0.45), Color(red: 0.09, green: 0.07, blue: 0.15)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    /// Vertical scrim that fades artwork into the base color for readable text.
    static func heroScrim(to color: Color = Palette.base) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: color.opacity(0.55), location: 0.6),
                .init(color: color, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
