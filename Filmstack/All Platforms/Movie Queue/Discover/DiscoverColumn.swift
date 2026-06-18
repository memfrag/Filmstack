//
//  Filmstack
//

import SwiftUI
import NukeUI

/// Browses a TMDB Discover list (now playing / popular / top rated / upcoming) as
/// a poster grid. Tapping a movie opens the add-to-queue confirmation.
struct DiscoverColumn: View {

    let list: DiscoverList

    @Environment(AppSettings.self) private var appSettings
    private let store = DiscoverStore.shared

    @State private var selectedResult: MovieSearchResult?

    private var region: String? { appSettings.releaseRegion }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .filmWindowBackground()
        .navigationTitle(list.title)
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await store.refresh(list, region: region) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.phase(for: list) == .loading)
            }
        }
        .task(id: list) {
            await store.ensureLoaded(list, region: region)
        }
        .sheet(item: $selectedResult) { result in
            addSheet(for: result)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(list.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            if case .loaded(let movies) = store.phase(for: list) {
                Text("\(movies.count) movies")
                    .font(.title3)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch store.phase(for: list) {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let movies) where movies.isEmpty:
            ContentUnavailableView("Nothing Here", systemImage: "film",
                                   description: Text("TMDB returned no movies for this list."))
        case .loaded(let movies):
            grid(movies)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await store.refresh(list, region: region) } }
            }
        }
    }

    private func grid(_ movies: [MovieSearchResult]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 116, maximum: 150), spacing: 16)],
                spacing: 18
            ) {
                ForEach(movies) { movie in
                    posterCard(movie)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func posterCard(_ movie: MovieSearchResult) -> some View {
        Button {
            selectedResult = movie
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                poster(movie)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Palette.hairline)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 5, y: 3)

                Text(movie.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func poster(_ movie: MovieSearchResult) -> some View {
        if let url = TMDBImage.posterURL(path: movie.posterPath, size: .detail) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
    }

    private func addSheet(for result: MovieSearchResult) -> some View {
        NavigationStack {
            AddMovieConfirmation(
                result: result,
                defaultStatus: .queued,
                model: MovieSearchModel(),
                onAdded: { selectedResult = nil }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selectedResult = nil }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 520)
    }
}
