//
//  Filmstack
//

import SwiftUI
import NukeUI

/// Poster artwork for a movie.
///
/// Loads (and caches) the poster from TMDB's public image CDN via Nuke's
/// `LazyImage`, falling back to a placeholder while loading, on failure, or when
/// the movie has no poster (e.g. manual entries).
struct PosterView: View {

    let movie: Movie
    var size: PosterSize = .queue
    var cornerRadius: CGFloat = 6

    private var posterURL: URL? {
        TMDBImage.posterURL(path: movie.posterPath, size: size)
    }

    var body: some View {
        content
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .accessibilityLabel("\(movie.title) poster")
    }

    @ViewBuilder private var content: some View {
        if let posterURL {
            LazyImage(url: posterURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else if state.error != nil {
                    placeholder
                } else {
                    placeholder.overlay {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.secondary)
            }
    }
}

#if DEBUG
#Preview {
    HStack {
        PosterView(movie: Movie(title: "No Poster"))
            .frame(height: 80)
        PosterView(movie: SampleMovies.makeMovies()[0], size: .detail)
            .frame(height: 220)
    }
    .padding()
}
#endif
