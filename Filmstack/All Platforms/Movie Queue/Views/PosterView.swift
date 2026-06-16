//
//  Filmstack
//

import SwiftUI

/// Poster artwork for a movie.
///
/// For now this always renders a placeholder. Once TMDB poster loading lands, this
/// is the single place that needs to learn how to fetch and cache real artwork.
struct PosterView: View {

    let movie: Movie
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.fill.tertiary)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .accessibilityLabel("\(movie.title) poster")
    }
}

#Preview {
    HStack {
        PosterView(movie: Movie(title: "Dune: Part Two"))
            .frame(height: 80)
        PosterView(movie: Movie(title: "Heat"))
            .frame(height: 160)
    }
    .padding()
}
