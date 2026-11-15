//
//  Filmstack
//

import SwiftUI
import NukeUI

/// A large card for the Browse tab: a list's name next to a fanned collage of
/// its top posters, on a soft, blurred wash of the first one.
struct BrowseCard: View {

    let title: String
    let subtitle: String
    let systemImage: String
    /// Poster images, front first; up to four are fanned out.
    let posterURLs: [URL]

    private let height: CGFloat = 132

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            fan
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
            label
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        // A background, so the scaled-to-fill image can't stretch the layout.
        .background { backdrop }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.hairline)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// The first poster, heavily blurred and darkened, behind everything.
    private var backdrop: some View {
        ZStack {
            Palette.elevated
            if let url = posterURLs.first {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    }
                }
                .blur(radius: 30)
                .opacity(0.55)
            }
            LinearGradient(
                colors: [Palette.base.opacity(0.85), Palette.base.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// The posters fanned out on the right: the first in front, the next two
    /// tilting away to the left behind it, and a fourth tilting to the right
    /// from behind the front one.
    @ViewBuilder private var fan: some View {
        let urls = Array(posterURLs.prefix(4))
        if urls.isEmpty {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.accentBright.opacity(0.5))
                .padding(.trailing, 12)
        } else {
            ZStack {
                // Drawn back to front.
                ForEach(Self.drawOrder.filter { $0 < urls.count }, id: \.self) { index in
                    let slot = Self.slots[index]
                    poster(urls[index])
                        .rotationEffect(.degrees(slot.angle))
                        .offset(x: slot.x, y: slot.y)
                }
            }
            // Room for the posters fanned out to the left of the front one. The
            // one tilting right is left to spill off the card's right edge.
            .padding(.leading, urls.count > 1 ? CGFloat(min(urls.count, 3) - 1) * 40 : 0)
            // Larger than the card, so the posters spill off its bottom edge.
            .offset(y: 26)
        }
    }

    /// Where each poster sits relative to the front one.
    private static let slots: [(x: CGFloat, y: CGFloat, angle: Double)] = [
        (0, 0, 0),        // front
        (-40, 4, -7),     // behind, left
        (-80, 8, -14),    // further behind, left
        (50, 4, 8),       // behind the front, right; spills off the edge
    ]

    /// Back to front: the far left, the right one, the near left, the front.
    private static let drawOrder = [2, 3, 1, 0]

    private func poster(_ url: URL) -> some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                Palette.card
            }
        }
        .frame(width: 88, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: 190, alignment: .leading)
    }
}
