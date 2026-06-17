//
//  Filmstack
//

import SwiftUI

/// A single row in the movie list column.
struct MovieRow: View {

    let movie: Movie
    /// Position number shown for queued movies (1-based). `nil` hides it.
    var position: Int?
    var isSelected: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let position {
                Text("\(position)")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Palette.textSecondary)
                    .frame(width: 20, alignment: .center)
            }

            PosterView(movie: movie, size: .queue, cornerRadius: 7)
                .frame(width: 52)
                .shadow(color: .black.opacity(0.45), radius: 5, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : Palette.textPrimary)
                    .lineLimit(1)

                Text(movie.metadataLine)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Palette.textSecondary)
                    .lineLimit(1)

                if !movie.userNotes.isEmpty {
                    Text(movie.userNotes)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Palette.textSecondary.opacity(0.85))
                        .lineLimit(1)
                } else if movie.status == .watched, let watched = movie.dateWatchedText {
                    Text("Watched \(watched)")
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Palette.textSecondary.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let rating = movie.tmdbRating {
                RatingBadge(rating: rating)
                    .opacity(isSelected ? 1 : 0.9)
            }
        }
        .padding(.vertical, 9)
        .padding(.trailing, 8)
        .padding(.leading, position == nil ? 8 : 4)
    }
}

#Preview {
    List {
        MovieRow(movie: SampleMovies.makeMovies()[0], position: 1, isSelected: true)
        MovieRow(movie: SampleMovies.makeMovies()[6], position: nil)
    }
    .scrollContentBackground(.hidden)
    .filmWindowBackground()
}
