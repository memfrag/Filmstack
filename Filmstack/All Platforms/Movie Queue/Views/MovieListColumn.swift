//
//  Filmstack
//

import SwiftUI
import SwiftData

/// The middle column of the main layout: the list of movies for one library
/// section (Queue / Watched / Maybe Later). Selecting a row drives the detail
/// column via the shared `selection` binding.
struct MovieListColumn: View {

    let section: MainRouting.Selectable
    @Binding var selection: Movie?

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query private var movies: [Movie]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var filter = LibraryFilter()
    @State private var showingFilterPopover = false
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    init(section: MainRouting.Selectable, selection: Binding<Movie?>) {
        self.section = section
        self._selection = selection

        let predicate: Predicate<Movie>
        let sort: [SortDescriptor<Movie>]
        let watchedRaw = MovieStatus.watched.rawValue
        switch section {
        case .queue:
            let raw = MovieStatus.queued.rawValue
            predicate = #Predicate { $0.statusRawValue == raw }
            sort = [SortDescriptor(\.queuePosition, order: .forward)]
        case .watched:
            let raw = MovieStatus.watched.rawValue
            predicate = #Predicate { $0.statusRawValue == raw }
            sort = [SortDescriptor(\.dateWatched, order: .reverse)]
        case .maybeLater:
            let raw = MovieStatus.maybeLater.rawValue
            predicate = #Predicate { $0.statusRawValue == raw }
            sort = [SortDescriptor(\.dateAdded, order: .reverse)]
        case .upcoming:
            // Any non-watched movie; future-dated ones are kept in `sectionMovies`.
            predicate = #Predicate { $0.statusRawValue != watchedRaw }
            sort = [SortDescriptor(\.releaseDate, order: .forward)]
        }
        _movies = Query(filter: predicate, sort: sort)
    }

    private var canReorder: Bool {
        section == .queue && searchText.isEmpty && !filter.isActive
    }

    /// Movies belonging to this section before user filters/search. For Upcoming
    /// this keeps only movies with a future release date.
    private var sectionMovies: [Movie] {
        guard section == .upcoming else { return movies }
        let now = Date()
        return movies.filter { ($0.releaseDate ?? .distantPast) > now }
    }

    private var filteredMovies: [Movie] {
        var result = filter.isActive ? sectionMovies.filter(filter.matches) : sectionMovies
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    /// Genres present in this section, sorted — the available genre filters.
    private var availableGenres: [String] {
        Set(sectionMovies.flatMap(\.genres)).sorted()
    }

    /// Sources present in this section, sorted — the available source filters.
    private var availableSources: [String] {
        Set(sectionMovies.compactMap { $0.source?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }).sorted()
    }

    /// Streaming locations present in this section, sorted.
    private var availableLocations: [String] {
        Set(sectionMovies.compactMap { $0.streamingLocation?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }).sorted()
    }

    private var hasFilters: Bool {
        !availableGenres.isEmpty || !availableSources.isEmpty || !availableLocations.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if filter.isActive {
                filterChips
            }
            if sectionMovies.isEmpty {
                emptyState
            } else if filteredMovies.isEmpty {
                noMatchesState
            } else {
                list
            }
        }
        .filmWindowBackground()
        .navigationTitle(section.title)
        .searchable(text: $searchText, prompt: "Search \(section.title.lowercased())")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddSheet) {
            AddMovieSheet(defaultStatus: section.defaultAddStatus ?? .queued)
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(section.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text(countText)
                .font(.title3)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filter.genres.sorted(), id: \.self) { genre in
                    FilterChip(label: genre, systemImage: "theatermasks") {
                        filter.toggleGenre(genre)
                    }
                }
                ForEach(filter.sources.sorted(), id: \.self) { source in
                    FilterChip(label: source, systemImage: "sparkles") {
                        filter.toggleSource(source)
                    }
                }
                ForEach(filter.locations.sorted(), id: \.self) { location in
                    FilterChip(label: location, systemImage: "play.tv") {
                        filter.toggleLocation(location)
                    }
                }
                if filter.activeCount > 1 {
                    Button("Clear All") { filter.clear() }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)
        }
    }

    // MARK: - List

    private var list: some View {
        List(selection: $selection) {
            ForEach(filteredMovies, id: \.persistentModelID) { movie in
                row(for: movie)
            }
            .onMove(perform: moveHandler)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    @ViewBuilder
    private func row(for movie: Movie) -> some View {
        let selected = movie.persistentModelID == selection?.persistentModelID
        MovieRow(movie: movie, position: position(for: movie), isSelected: selected)
            .tag(movie)
            //.listRowBackground(rowBackground(selected: selected))
            //.listRowSeparator(.hidden)
            .listRowSeparatorTint(Palette.card)
            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                dimensions.width
            }
            .contextMenu { rowMenu(for: movie) }
            #if os(iOS)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions(for: movie)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                leadingSwipeActions(for: movie)
            }
            #endif
    }

    private func rowBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.card)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.white.opacity(0.22) : Palette.hairline)
            }
            .shadow(color: selected ? Palette.accent.opacity(0.35) : .clear, radius: 8, y: 3)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
    }

    #if os(iOS)
    @ViewBuilder
    private func trailingSwipeActions(for movie: Movie) -> some View {
        Button(role: .destructive) {
            deleteMovie(movie)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        if movie.status != .watched {
            Button {
                MovieActions.markWatched(movie, in: context)
            } label: {
                Label("Watched", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
    }

    @ViewBuilder
    private func leadingSwipeActions(for movie: Movie) -> some View {
        if movie.status != .maybeLater {
            Button {
                MovieActions.moveToMaybeLater(movie, in: context)
            } label: {
                Label("Maybe Later", systemImage: "clock")
            }
            .tint(.orange)
        }
        if movie.status != .queued {
            Button {
                MovieActions.moveBackToQueue(movie, in: context)
            } label: {
                Label("Queue", systemImage: "list.bullet")
            }
            .tint(.blue)
        }
    }
    #endif

    @ViewBuilder
    private func rowMenu(for movie: Movie) -> some View {
        if movie.status == .queued {
            Button("Move to Top") { MovieActions.moveToTop(movie, in: context) }
            Button("Move to Bottom") { MovieActions.moveToBottom(movie, in: context) }
            Divider()
        }

        if movie.status != .queued {
            Button("Move to Queue") { MovieActions.moveBackToQueue(movie, in: context) }
        }
        if movie.status != .maybeLater {
            Button("Move to Maybe Later") { MovieActions.moveToMaybeLater(movie, in: context) }
        }
        if movie.status != .watched {
            Button("Mark as Watched") { MovieActions.markWatched(movie, in: context) }
        }

        Divider()
        Button("Open in Letterboxd") {
            if let url = letterboxdURL(for: movie) { openURL(url) }
        }
        Button("Open in IMDb") {
            if let url = imdbURL(for: movie) { openURL(url) }
        }

        Divider()
        Button("Delete", role: .destructive) {
            deleteMovie(movie)
        }
    }

    private func deleteMovie(_ movie: Movie) {
        if selection?.persistentModelID == movie.persistentModelID {
            selection = nil
        }
        MovieActions.delete(movie, in: context)
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
        guard section.showsPosition else { return nil }
        guard let index = movies.firstIndex(where: { $0.persistentModelID == movie.persistentModelID }) else {
            return nil
        }
        return index + 1
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: section.systemImage)
            } description: {
                Text(emptyMessage)
            } actions: {
                if section.defaultAddStatus != nil {
                    Button("Add Movie") { showingAddSheet = true }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyTitle: String {
        switch section {
        case .queue: "Your movie queue is empty"
        case .upcoming: "Nothing upcoming"
        case .watched: "Nothing watched yet"
        case .maybeLater: "Nothing on the maybe list"
        }
    }

    private var emptyMessage: String {
        switch section {
        case .queue: "Add something you want to watch."
        case .upcoming: "Movies in your library with a future release date show up here."
        case .watched: "Movies you mark as watched will show up here."
        case .maybeLater: "Park movies here when you're not sure yet."
        }
    }

    private var noMatchesState: some View {
        ContentUnavailableView {
            Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text(searchText.isEmpty
                 ? "No movies in \(section.title) match this filter."
                 : "No movies match your search.")
        }
    }

    // MARK: - Toolbar

    private var countText: String {
        let count = filteredMovies.count
        return count == 1 ? "1 movie" : "\(count) movies"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if hasFilters {
            ToolbarItem {
                Button {
                    showingFilterPopover = true
                } label: {
                    Label("Filter", systemImage: filter.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $showingFilterPopover, arrowEdge: .bottom) {
                    FilterPopover(
                        filter: $filter,
                        genres: availableGenres,
                        sources: availableSources,
                        locations: availableLocations
                    )
                }
            }
            ToolbarSpacer(.fixed)
        }
        if section.defaultAddStatus != nil {
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
        MovieListColumn(section: .queue, selection: .constant(nil))
    }
    .modelContainer(MovieStore.previewContainer)
}
