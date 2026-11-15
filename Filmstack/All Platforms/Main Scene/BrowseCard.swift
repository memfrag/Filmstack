//
//  Filmstack
//

import SwiftUI
import NukeUI

/// A large card for the Browse tab: a list's name over a fanned collage of
/// its top posters, on a soft, blurred wash of the first one.
struct BrowseCard: View {

    let title: String
    let subtitle: String
    let systemImage: String
    /// Poster images, front first; up to three are fanned out.
    let posterURLs: [URL]

    private let height: CGFloat = 132

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            fan
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
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

    /// Up to three posters fanned out on the right, the first in front.
    @ViewBuilder private var fan: some View {
        let urls = Array(posterURLs.prefix(3))
        if urls.isEmpty {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.accentBright.opacity(0.5))
                .padding(.trailing, 12)
        } else {
            ZStack {
                // Back to front, so the first poster ends up on top.
                ForEach(Array(urls.enumerated()).reversed(), id: \.offset) { index, url in
                    poster(url)
                        .rotationEffect(.degrees(Double(index) * -7))
                        .offset(x: CGFloat(index) * -30, y: CGFloat(index) * 4)
                }
            }
            .padding(.trailing, CGFloat(urls.count - 1) * 30)
        }
    }

    private func poster(_ url: URL) -> some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                Palette.card
            }
        }
        .frame(width: 62, height: 93)
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
