//
//  Filmstack
//

import SwiftUI
import NukeUI

/// The front of a DVD keep case: black plastic shell framing the poster,
/// with a glossy sheen.
struct DVDFrontFace: View {

    let movie: Movie
    let size: CGSize

    /// Square outer corners, so the front and back meet the flat spine,
    /// edge, top and bottom faces cleanly.
    private let corner: CGFloat = 0
    private var margin: CGFloat { size.width * 0.035 }

    var body: some View {
        ZStack(alignment: .top) {
            shell

            cover
                .padding(margin)
        }
        .frame(width: size.width, height: size.height)
        .overlay { sheen }
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var shell: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Palette.dvdCase, Palette.dvdCaseDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var cover: some View {
        Rectangle()
            .fill(.black.opacity(0.35))
            .overlay {
                CoverArt(movie: movie, size: .detail)
            }
            .clipShape(RoundedRectangle(cornerRadius: size.width * 0.018, style: .continuous))
    }

    private var sheen: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.28), location: 0.0),
                .init(color: .white.opacity(0.06), location: 0.32),
                .init(color: .clear, location: 0.33),
                .init(color: .clear, location: 0.7),
                .init(color: .white.opacity(0.08), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }
}

/// The case's spine: a narrow strip of darker plastic with the title set
/// vertically and the queue position.
struct DVDSpineFace: View {

    let movie: Movie
    let position: Int?
    let size: CGSize

    var body: some View {
        // Laid out horizontally (height × width), then turned upright.
        HStack(spacing: size.width * 0.4) {
            if let position {
                Text("\(position)")
                    .font(.system(size: size.width * 0.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Text(movie.title.uppercased())
                .font(.system(size: size.width * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, size.width * 0.6)
        .frame(width: size.height, height: size.width)
        .background(
            LinearGradient(
                colors: [Palette.dvdCaseDark, Palette.dvdCase.opacity(0.85), Palette.dvdCaseDark],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay {
            Rectangle().strokeBorder(.white.opacity(0.15), lineWidth: 0.75)
        }
        .rotationEffect(.degrees(90))
        .frame(width: size.width, height: size.height)
    }
}

/// A plain side of the case (top, bottom, opening edge, or the back when not
/// showing the synopsis): dark plastic with a faint highlight.
struct DVDEdgeFace: View {

    let size: CGSize
    var shade: CGFloat = 0
    /// Top edges catch the light, so they're lighter; this keeps each case's
    /// top reading as part of the case rather than a stray dark bar.
    var isTop = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: isTop
                        ? [Color(white: 0.34), Color(white: 0.22)]
                        : [Palette.dvdCase, Palette.dvdCaseDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay { Rectangle().strokeBorder(.white.opacity(0.12), lineWidth: 0.75) }
            .overlay { Color.black.opacity(shade) }
            .frame(width: size.width, height: size.height)
    }
}

/// The back of the case: synopsis and credits, with a way into full details.
struct DVDBackFace: View {

    let movie: Movie
    let position: Int?
    let size: CGSize
    let onOpenDetails: () -> Void

    /// Square outer corners, so the front and back meet the flat spine,
    /// edge, top and bottom faces cleanly.
    private let corner: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if let rating = movie.tmdbRating, rating > 0 {
                    RatingBadge(rating: rating)
                }
            }

            if !movie.metadataLine.isEmpty {
                Text(movie.metadataLine)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }

            if let overview = movie.overview, !overview.isEmpty {
                // Plain text, not a ScrollView: a scroll view is a separate
                // platform layer that renders blurry under the 3D projection.
                // Long synopses are truncated; Open Full Details has the rest.
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Spacer(minLength: 0)
            }

            credits

            Button(action: onOpenDetails) {
                Label("Open Full Details", systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.filmGlass)
        }
        .padding(size.width * 0.06)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Palette.dvdCase, Palette.dvdCaseDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                CoverArt(movie: movie, size: .queue)
                    .blur(radius: 24)
                    .opacity(0.35)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    @ViewBuilder private var credits: some View {
        let lines = [
            movie.director.map { "Directed by \($0)" },
            movie.cast.isEmpty ? nil : "Starring " + movie.cast.prefix(3).joined(separator: ", ")
        ].compactMap { $0 }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
    }
}

/// Poster artwork filling its frame (cropped), with a quiet placeholder.
struct CoverArt: View {

    let movie: Movie
    let size: PosterSize

    var body: some View {
        if let url = TMDBImage.posterURL(path: movie.posterPath, size: size) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Palette.elevated)
            VStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.title2)
                Text(movie.title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
            .foregroundStyle(Palette.textSecondary)
        }
    }
}

#if DEBUG
#Preview {
    let movie = SampleMovies.makeMovies()[0]
    HStack(spacing: 16) {
        DVDFrontFace(movie: movie, size: CGSize(width: 200, height: 253))
        DVDSpineFace(movie: movie, position: 3, size: CGSize(width: 22, height: 253))
        DVDBackFace(movie: movie, position: 3, size: CGSize(width: 200, height: 253)) {}
    }
    .padding()
    .background(Palette.base)
}
#endif
