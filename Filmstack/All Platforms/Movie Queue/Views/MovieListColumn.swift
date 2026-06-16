//
//  Filmstack
//

import SwiftUI
import SwiftData

/// The middle column of the main layout: the list of movies for one library
/// section (Queue / Watched / Maybe Later). Selecting a row drives the detail
/// column via the shared `selection` binding.
struct MovieListColumn: View {

    let status: MovieStatus
    @Binding var selection: Movie?

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query private var movies: [Movie]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    init(status: MovieStatus, selection: Binding<Movie?>) {
        self.status = status
        self._selection = selection

        let raw = status.rawValue
        let sort: [SortDescriptor<Movie>]
        switch status {
        case .queued:
            sort = [SortDescriptor(\.queuePosition, order: .forward)]
        case .watched:
            sort = [SortDescriptor(\.dateWatched, order: .reverse)]
        case .maybeLater:
            sort = [SortDescriptor(\.dateAdded, order: .reverse)]
        }
        _movies = Query(filter: #Predicate { $0.statusRawValue == raw }, sort: sort)
    }

    private var canReorder: Bool {
        status == .queued && searchText.isEmpty
    }

    private var filteredMovies: [Movie] {
        guard !searchText.isEmpty else { return movies }
        return movies.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if movies.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(status.title)
        #if os(macOS)
        .navigationSubtitle(countText)
        #endif
        .searchable(text: $searchText, prompt: "Search \(status.title.lowercased())")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddSheet) {
            AddMovieSheet(defaultStatus: status)
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsScreen()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }

    // MARK: - List

    private var list: some View {
        List(selection: $selection) {
            ForEach(filteredMovies, id: \.persistentModelID) { movie in
                row(for: movie)
            }
            .onMove(perform: moveHandler)
        }
    }

    @ViewBuilder
    private func row(for movie: Movie) -> some View {
        MovieRow(movie: movie, position: position(for: movie))
            .tag(movie)
            .contextMenu { rowMenu(for: movie) }
    }

    @ViewBuilder
    private func rowMenu(for movie: Movie) -> some View {
        if status == .queued {
            Button("Move to Top") { MovieActions.moveToTop(movie, in: context) }
            Button("Move to Bottom") { MovieActions.moveToBottom(movie, in: context) }
            Divider()
        }

        if status != .queued {
            Button("Move to Queue") { MovieActions.moveBackToQueue(movie, in: context) }
        }
        if status != .maybeLater {
            Button("Move to Maybe Later") { MovieActions.moveToMaybeLater(movie, in: context) }
        }
        if status != .watched {
            Button("Mark as Watched") { MovieActions.markWatched(movie, in: context) }
        }

        Divider()
        Button("Open in Letterboxd") {
            if let url = letterboxdURL(for: movie) { openURL(url) }
        }

        Divider()
        Button("Delete", role: .destructive) {
            if selection?.persistentModelID == movie.persistentModelID {
                selection = nil
            }
            MovieActions.delete(movie, in: context)
        }
    }

    private var moveHandler: ((IndexSet, Int) -> Void)? {
        guard canReorder else { return nil }
        return { offsets, destination in
            var reordered = movies
            reordered.move(fromOffsets: offsets, toOffset: destination)
            MovieActions.reorderQueue(reordered, in: context)
        }
    }

    private func position(for movie: Movie) -> Int? {
        guard status == .queued else { return nil }
        guard let index = movies.firstIndex(where: { $0.persistentModelID == movie.persistentModelID }) else {
            return nil
        }
        return index + 1
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: status.systemImage)
        } description: {
            Text(emptyMessage)
        } actions: {
            if status != .watched {
                Button("Add Movie") { showingAddSheet = true }
            }
        }
    }

    private var emptyTitle: String {
        switch status {
        case .queued: "Your movie queue is empty"
        case .watched: "Nothing watched yet"
        case .maybeLater: "Nothing on the maybe list"
        }
    }

    private var emptyMessage: String {
        switch status {
        case .queued: "Add something you want to watch."
        case .watched: "Movies you mark as watched will show up here."
        case .maybeLater: "Park movies here when you're not sure yet."
        }
    }

    // MARK: - Toolbar

    private var countText: String {
        movies.count == 1 ? "1 movie" : "\(movies.count) movies"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if status != .watched {
            ToolbarItem {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Movie", systemImage: "plus")
                }
            }
        }
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        MovieListColumn(status: .queued, selection: .constant(nil))
    }
    .modelContainer(MovieStore.previewContainer)
}
