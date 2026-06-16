//
//  Filmstack
//

import SwiftUI
import NukeUI

/// The detail column — the most cinematic surface in the app. A wide hero image
/// (backdrop, or a blurred poster as a fallback) fades into the base color, with
/// the poster overlapping below it and the title set large and bold.
struct MovieDetailColumn: View {

    @Binding var selection: Movie?

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    private let heroHeight: CGFloat = 220

    var body: some View {
        Group {
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
                emptyState
            }
        }
        .background(Palette.base)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "film.stack")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.8))
            Text("No Movie Selected")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            Text("Select a movie to see its details.")
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private func content(for movie: Movie) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero(for: movie)

                    posterAndTitle(for: movie)
                        .padding(.horizontal, 24)
                        .padding(.top, -70)

                    VStack(alignment: .leading, spacing: 22) {
                        if let overview = movie.overview, !overview.isEmpty {
                            section("Overview") { Text(overview) }
                        }
                        if !movie.cast.isEmpty {
                            section("Cast") { Text(movie.cast.joined(separator: ", ")) }
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            actionBar(for: movie)
        }
    }

    // MARK: - Hero

    private func hero(for movie: Movie) -> some View {
        ZStack(alignment: .topTrailing) {
            heroImage(for: movie)
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay { Gradients.heroScrim() }

            if let rating = movie.tmdbRating {
                RatingBadge(rating: rating)
                    .padding(16)
            }
        }
        .frame(height: heroHeight)
    }

    @ViewBuilder private func heroImage(for movie: Movie) -> some View {
        if let backdrop = TMDBImage.backdropURL(path: movie.backdropPath) {
            LazyImage(url: backdrop) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Gradients.hero
                }
            }
        } else if let poster = TMDBImage.posterURL(path: movie.posterPath, size: .detail) {
            // No backdrop: use a blurred, dimmed poster as an ambient hero.
            LazyImage(url: poster) { state in
                if let image = state.image {
                    image.resizable().scaledToFill().blur(radius: 38).opacity(0.55)
                } else {
                    Gradients.hero
                }
            }
        } else {
            Gradients.hero
        }
    }

    // MARK: - Poster + title

    private func posterAndTitle(for movie: Movie) -> some View {
        HStack(alignment: .bottom, spacing: 18) {
            PosterView(movie: movie, size: .detail, cornerRadius: 12)
                .frame(width: 132)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 2) {
                    if let meta = metaLine(for: movie) {
                        Text(meta)
                    }
                    if let genres = movie.genresText {
                        Text(genres)
                    }
                }
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)

                HStack(spacing: 24) {
                    if let director = movie.director, !director.isEmpty {
                        labeledField("Director", director)
                    }
                    if let release = movie.releaseDateText {
                        labeledField("Release Date", release)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 6)

            Spacer(minLength: 0)
        }
    }

    private func metaLine(for movie: Movie) -> String? {
        let value = [movie.yearText, movie.runtimeText]
            .compactMap { $0 }
            .joined(separator: " · ")
        return value.isEmpty ? nil : value
    }

    private func labeledField(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(Palette.accentBright)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(Palette.accentBright)
            content()
                .font(.body)
                .foregroundStyle(Palette.textPrimary.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func actionBar(for movie: Movie) -> some View {
        HStack(spacing: 12) {
            if movie.status == .watched {
                Button {
                    MovieActions.moveBackToQueue(movie, in: context)
                } label: {
                    Label("Move to Queue", systemImage: "arrow.uturn.left.circle.fill")
                }
                .buttonStyle(.filmAccent)
            } else {
                Button {
                    MovieActions.markWatched(movie, in: context)
                } label: {
                    Label("Mark as Watched", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.filmAccent)
            }

            Button {
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.filmGlass)

            Menu {
                if movie.status == .queued {
                    Button("Move to Top") { MovieActions.moveToTop(movie, in: context) }
                    Button("Move to Bottom") { MovieActions.moveToBottom(movie, in: context) }
                    Divider()
                }
                Button("Open in Letterboxd") { open(letterboxdURL(for: movie)) }
                Button("Open in IMDb") { open(imdbURL(for: movie)) }
                Divider()
                Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.filmGlass)
            .fixedSize()

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.separator).frame(height: 1)
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}

#Preview {
    MovieDetailColumn(selection: .constant(SampleMovies.makeMovies().first))
        .modelContainer(MovieStore.previewContainer)
        .frame(width: 420, height: 760)
}
