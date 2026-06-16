//
//  Filmstack
//

import SwiftUI

/// Primary call-to-action button: violet gradient with a soft accent glow.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(Gradients.accentButton, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(0.18))
            }
            .shadow(color: Palette.accent.opacity(0.45), radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary button: translucent glassy surface with a thin border.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.textPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static var filmAccent: AccentButtonStyle { AccentButtonStyle() }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var filmGlass: GlassButtonStyle { GlassButtonStyle() }
}

// MARK: - Surfaces

extension View {

    /// Paints the cinematic window-wide gradient behind this view.
    func filmWindowBackground() -> some View {
        background(Gradients.window.ignoresSafeArea())
    }

    /// Wraps content in a rounded, softly bordered glass card.
    func filmCard(cornerRadius: CGFloat = 14) -> some View {
        background(Palette.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.hairline)
            }
    }
}

/// A small star-rating pill, e.g. for TMDB's community score on the hero.
struct RatingBadge: View {
    /// Rating on a 0–10 scale.
    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.black.opacity(0.45), in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
    }
}
