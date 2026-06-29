//
//  Filmstack
//

import SwiftUI
import NukeUI

/// Search-first Add Movie flow: type a title, search TMDB (debounced), pick a
/// result, then confirm details before adding to the library. Manual entry is
/// always available as a fallback.
struct AddMovieSheet: View {

    let defaultStatus: MovieStatus

    @Environment(\.dismiss) private var dismiss
    @State private var model = MovieSearchModel()
    @State private var showingManualAdd = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                content
                    .frame(maxHeight: .infinity)
            }
            .navigationTitle("Add Movie")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Manually") { showingManualAdd = true }
                }
            }
            .navigationDestination(for: MovieSearchResult.self) { result in
                AddMovieConfirmation(
                    result: result,
                    defaultStatus: defaultStatus,
                    model: model,
                    onAdded: { dismiss() }
                )
            }
            .sheet(isPresented: $showingManualAdd) {
                MovieFormSheet(mode: .add(defaultStatus: defaultStatus))
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
        .task(id: model.query) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await model.search()
        }
        .onAppear { searchFocused = true }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search movies on TMDB", text: $model.query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .focused($searchFocused)
            if case .searching = model.phase {
                ProgressView().controlSize(.small)
            } else if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .noToken:
            noTokenView
        case .idle:
            message("Search TMDB", "Type at least \(MovieSearchModel.minimumQueryLength) characters to find a movie.", "magnifyingglass")
        case .searching:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results(let results):
            resultsList(results)
        case .empty:
            message("No movies found", "Try a different title, or add the movie manually.", "film")
        case .failed(let text):
            failedView(text)
        }
    }

    private func resultsList(_ results: [MovieSearchResult]) -> some View {
        List(results) { result in
            NavigationLink(value: result) {
                SearchResultRow(result: result)
            }
        }
        .listStyle(.inset)
    }

    private var noTokenView: some View {
        ContentUnavailableView {
            Label("TMDB Key Required", systemImage: "key.horizontal")
        } description: {
            Text("Movie search requires a TMDB API key. Add one in Settings, or add a movie manually.")
        } actions: {
            #if os(macOS)
            SettingsLink { Text("Open Settings") }
            #endif
            Button("Add Manually") { showingManualAdd = true }
        }
    }

    private func failedView(_ text: String) -> some View {
        ContentUnavailableView {
            Label("Search Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(text)
        } actions: {
            Button("Try Again") {
                Task { await model.search() }
            }
            Button("Add Manually") { showingManualAdd = true }
        }
    }

    private func message(_ title: String, _ description: String, _ symbol: String) -> some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(description))
    }
}

// MARK: - Result row

private struct SearchResultRow: View {

    let result: MovieSearchResult

    private var thumbnailURL: URL? {
        result.posterThumbnailURL ?? TMDBImage.posterURL(path: result.posterPath, size: .thumbnail)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster
                .frame(width: 46, height: 69)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(1)
                if let year = result.releaseYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let overview = result.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var poster: some View {
        if let thumbnailURL {
            LazyImage(url: thumbnailURL) { state in
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
}

#Preview {
    AddMovieSheet(defaultStatus: .queued)
        .appEnvironment(.mock())
        .modelContainer(MovieStore.previewContainer)
}
