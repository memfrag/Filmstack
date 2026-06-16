//
//  Filmstack
//

import SwiftUI

/// A single row in the movie list column.
struct MovieRow: View {

    let movie: Movie
    /// Position number shown for queued movies (1-based). `nil` hides it.
    var position: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let position {
                Text("\(position)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)
                    .padding(.top, 2)
            }

            PosterView(movie: movie)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(movie.metadataLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !movie.userNotes.isEmpty {
                    Text(movie.userNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if movie.status == .watched, let watched = movie.dateWatchedText {
                    Text("Watched \(watched)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        MovieRow(movie: SampleMovies.makeMovies()[0], position: 1)
        MovieRow(movie: SampleMovies.makeMovies()[6], position: nil)
    }
}
