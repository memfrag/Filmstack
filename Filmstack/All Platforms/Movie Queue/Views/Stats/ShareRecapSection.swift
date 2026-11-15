//
//  Filmstack
//

import SwiftUI
import Nuke

/// What goes on the shared recap image; all of it from the statistics, plus
/// the written headline when there is one.
struct ShareRecapContent: Hashable {
    let year: Int
    let count: Int
    let headline: String
    let favoriteGenre: String?
    let busiestMonth: String?
    let topRatedTitle: String?
    let topRatedRating: Double?
    let posterURL: URL?

    init(facts: WatchedStats.YearFacts, headline: String?, topRatedMovie: Movie?) {
        year = facts.year
        count = facts.count
        self.headline = headline ?? String(localized: "My \(String(facts.year)) in Movies")
        favoriteGenre = facts.favoriteGenre?.name
        busiestMonth = facts.busiestMonth.map {
            "\($0.start.formatted(.dateTime.month(.wide))) · \($0.count == 1 ? "1 movie" : "\($0.count) movies")"
        }
        topRatedTitle = facts.topRated?.title
        topRatedRating = facts.topRated?.rating
        posterURL = TMDBImage.posterURL(path: topRatedMovie?.posterPath, size: .detail)
    }
}

/// "Share Your Year": a preview of the recap image and a share button.
struct ShareRecapSection: View {

    let content: ShareRecapContent

    @State private var image: Image?

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let image {
                    image.resizable().scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Palette.card)
                        .overlay { ProgressView().controlSize(.small) }
                }
            }
            .frame(width: 72, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Share Your Year")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("A card with your \(String(content.year)) in movies, made for sharing.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let image {
                    ShareLink(item: image,
                              preview: SharePreview("My \(String(content.year)) in Movies", image: image)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.filmAccent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .filmCard(cornerRadius: 20)
        .task(id: content) { await render() }
    }

    /// Draws the share card off screen, with the top-rated poster loaded
    /// through the app's image pipeline (and its cache) first.
    private func render() async {
        var poster: Image?
        if let url = content.posterURL,
           let loaded = try? await ImagePipeline.shared.image(for: url) {
            #if os(macOS)
            poster = Image(nsImage: loaded)
            #else
            poster = Image(uiImage: loaded)
            #endif
        }
        guard !Task.isCancelled else { return }
        let renderer = ImageRenderer(content: ShareRecapCard(content: content, poster: poster))
        renderer.scale = 3
        if let cgImage = renderer.cgImage {
            image = Image(decorative: cgImage, scale: 1)
        }
    }
}

/// The shared image: a fixed-size portrait card, independent of the screen.
struct ShareRecapCard: View {

    let content: ShareRecapContent
    let poster: Image?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "film.stack.fill")
                Text("Filmstack")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.accentBright)

            Spacer(minLength: 24)

            Text("My \(String(content.year)) in Movies")
                .font(.system(size: 13, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Palette.accentBright)
            Text("\(content.count)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Text(content.count == 1 ? "movie watched" : "movies watched")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.textSecondary)

            Text(content.headline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.top, 20)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 14) {
                if let genre = content.favoriteGenre {
                    fact("Favorite genre", genre, symbol: "theatermasks.fill")
                }
                if let month = content.busiestMonth {
                    fact("Busiest month", month, symbol: "calendar")
                }
                if let title = content.topRatedTitle {
                    HStack(spacing: 12) {
                        if let poster {
                            poster.resizable().scaledToFill()
                                .frame(width: 48, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        fact("Highest rated",
                             content.topRatedRating.map { "\(title) · \($0.formatted(.number.precision(.fractionLength(0...1))))★" } ?? title,
                             symbol: "star.fill")
                    }
                }
            }

            Spacer(minLength: 24)

            Text("Made with Filmstack")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary.opacity(0.7))
        }
        .padding(32)
        .frame(width: 360, height: 640, alignment: .topLeading)
        .background {
            ZStack {
                Palette.base
                LinearGradient(colors: [Color(red: 0.30, green: 0.17, blue: 0.52), .clear],
                               startPoint: .top, endPoint: .center)
                RadialGradient(colors: [Palette.accent.opacity(0.35), .clear],
                               center: .bottomTrailing, startRadius: 10, endRadius: 360)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func fact(_ label: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.accentBright)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
        }
    }
}

#if DEBUG
#Preview("Share card") {
    ShareRecapCard(
        content: ShareRecapContent(
            facts: WatchedStats(entries: SampleMovies.makeMovies().compactMap(\.watchedEntry))
                .facts(forYear: Calendar.current.component(.year, from: Date())),
            headline: "The Year of the Slow Burn", topRatedMovie: nil),
        poster: nil)
}
#endif
