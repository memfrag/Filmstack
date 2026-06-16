//
//  Filmstack
//

import SwiftUI

/// The detail column of the main layout. Shows the selected movie and its actions,
/// or a placeholder when nothing is selected.
struct MovieDetailColumn: View {

    @Binding var selection: Movie?

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        if let movie = selection {
            content(for: movie)
                .sheet(isPresented: $showingEditSheet) {
                    MovieFormSheet(mode: .edit(movie))
                }
                .confirmationDialog(
                    "Delete \(movie.title)?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        MovieActions.delete(movie, in: context)
                        selection = nil
                    }
                } message: {
                    Text("This removes the movie from your library.")
                }
        } else {
            ContentUnavailableView(
                "No Movie Selected",
                systemImage: "film",
                description: Text("Select a movie to see its details.")
            )
        }
    }

    // MARK: - Content

    private func content(for movie: Movie) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PosterView(movie: movie, cornerRadius: 10)
                        .frame(maxWidth: 220)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    header(for: movie)

                    if let overview = movie.overview, !overview.isEmpty {
                        section("Overview") { Text(overview) }
                    }

                    if !movie.userNotes.isEmpty {
                        section("My Notes") { Text(movie.userNotes) }
                    }

                    if let location = movie.streamingLocation, !location.isEmpty {
                        section("Where to Watch") { Text(location) }
                    }

                    if let source = movie.source, !source.isEmpty {
                        section("Heard About It From") { Text(source) }
                    }

                    section("Added") { Text(movie.dateAddedText) }

                    if let watched = movie.dateWatchedText {
                        section("Watched") { Text(watched) }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            actionBar(for: movie)
                .padding(16)
        }
    }

    private func header(for movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(movie.title)
                .font(.title.bold())

            if let meta = headerMetaLine(for: movie) {
                Text(meta).foregroundStyle(.secondary)
            }
            if let genres = movie.genresText {
                Text(genres).foregroundStyle(.secondary)
            }
            if let release = movie.releaseDateText {
                Text("Released \(release)")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func headerMetaLine(for movie: Movie) -> String? {
        [movie.yearText, movie.runtimeText]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
                .font(.body)
        }
    }

    // MARK: - Actions

    private func actionBar(for movie: Movie) -> some View {
        HStack(spacing: 10) {
            if movie.status == .watched {
                Button {
                    MovieActions.moveBackToQueue(movie, in: context)
                } label: {
                    Label("Move to Queue", systemImage: "arrow.uturn.left.circle")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    MovieActions.markWatched(movie, in: context)
                } label: {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Menu {
                if movie.status == .queued {
                    Button("Move to Top") { MovieActions.moveToTop(movie, in: context) }
                    Button("Move to Bottom") { MovieActions.moveToBottom(movie, in: context) }
                    Divider()
                }
                Button("Open in Letterboxd") { openLetterboxd(for: movie) }
                Divider()
                Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer(minLength: 0)
        }
    }

    private func openLetterboxd(for movie: Movie) {
        guard let url = letterboxdURL(for: movie) else { return }
        openURL(url)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
    MovieDetailColumn(selection: .constant(SampleMovies.makeMovies().first))
        .modelContainer(MovieStore.previewContainer)
        .frame(width: 360, height: 700)
}
