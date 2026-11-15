//
//  Filmstack
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

/// How the section's movies are laid out.
enum LibraryViewMode: String {
    case list
    case grid
}

/// The middle column of the main layout: the list of movies for one library
/// section (Queue / Watched / Maybe Later). Selecting a row drives the detail
/// column via the shared `selection` binding.
struct MovieListColumn: View {

    let section: MainRouting.Selectable
    @Binding var selection: Movie?

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var appSettings
    @Query private var movies: [Movie]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var filter = LibraryFilter()
    @State private var showingFilterPopover = false
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool
    @State private var showingPicker = false
    @State private var showingStats = false
    /// List or grid, remembered per section (see `init`).
    @AppStorage("filmstack.libraryViewMode") private var viewModeRaw = LibraryViewMode.list.rawValue
    /// Upcoming only: show releases as a poster-wall calendar (the default) instead of list/grid.
    @AppStorage("filmstack.upcomingCalendar") private var upcomingCalendar = true
    /// Watched only: show watch dates as a calendar (off by default).
    @AppStorage("filmstack.watchedCalendar") private var watchedCalendar = false

    private var viewMode: LibraryViewMode {
        LibraryViewMode(rawValue: viewModeRaw) ?? .list
    }

    private var showsCalendar: Bool {
        switch section {
        case .upcoming: upcomingCalendar
        case .watched: watchedCalendar
        default: false
        }
    }

    /// Whether this section offers a calendar layout.
    private var hasCalendar: Bool { section == .upcoming || section == .watched }

    init(section: MainRouting.Selectable, selection: Binding<Movie?>) {
        self.section = section
        self._selection = selection
        _viewModeRaw = AppStorage(wrappedValue: LibraryViewMode.list.rawValue,
                                  "filmstack.libraryViewMode.\(Self.storageName(for: section))")

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
        case .discover, .letterboxd, .profile:
            // External-browse sections use their own columns, never this view.
            predicate = #Predicate { _ in false }
            sort = []
        }
        _movies = Query(filter: predicate, sort: sort)
    }

    /// A stable name for a section in stored preferences.
    private static func storageName(for section: MainRouting.Selectable) -> String {
        switch section {
        case .queue: "queue"
        case .upcoming: "upcoming"
        case .watched: "watched"
        case .maybeLater: "maybeLater"
        case .discover(let list): "discover.\(list.rawValue)"
        case .letterboxd: "letterboxd"
        case .profile: "profile"
        }
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
        content
        .safeAreaBar(edge: .top) {
            VStack(spacing: 0) {
                header
                if filter.isActive {
                    filterChips
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: filter.isActive)
        .animation(.smooth(duration: 0.25), value: showingSearch)
        .animation(.smooth(duration: 0.3), value: viewMode)
        .animation(.smooth(duration: 0.3), value: showsCalendar)
        .filmWindowBackground()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        #else
        .navigationTitle(section.title)
        #endif
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddSheet) {
            AddMovieSheet(defaultStatus: section.defaultAddStatus ?? .queued)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: isPhone ? $showingPicker : .constant(false)) {
            moviePicker
        }
        .sheet(isPresented: isPhone ? .constant(false) : $showingPicker) {
            moviePicker
                .presentationSizing(.page)
        }
        #else
        .sheet(isPresented: $showingPicker) {
            moviePicker
                .frame(minWidth: 900, idealWidth: 960, minHeight: 640, idealHeight: 700)
        }
        #endif
        .sheet(isPresented: $showingStats) {
            WatchedStatsView(movies: sectionMovies)
                #if os(macOS)
                .frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 560)
                #endif
        }
    }

    /// The section's movies, or whichever empty state applies. Kept separate from
    /// `body` so the header can be attached as a top bar that the content scrolls
    /// beneath.
    @ViewBuilder private var content: some View {
        if sectionMovies.isEmpty {
            emptyState
        } else if filteredMovies.isEmpty {
            noMatchesState
        } else if showsCalendar {
            MovieCalendarView(movies: filteredMovies,
                              kind: section == .watched ? .watched : .release,
                              selection: $selection) { movie in
                rowMenu(for: movie)
            }
            .transition(.opacity)
        } else if viewMode == .grid {
            grid
                .transition(.opacity)
        } else {
            list
                .transition(.opacity)
        }
    }

    // MARK: - Movie picker

    #if os(iOS)
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    #endif

    private var moviePicker: some View {
        MoviePickerView(
            movies: filteredMovies,
            title: section.title,
            position: position(for:),
            onOpenDetails: { selection = $0 }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(section.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(countText)
                    .font(.title3)
                    .foregroundStyle(Palette.textSecondary)
                    .contentTransition(.numericText(value: Double(filteredMovies.count)))
                    .animation(.smooth(duration: 0.25), value: filteredMovies.count)
                Spacer()
            }
            if showingSearch {
                searchField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// Lives in the header rather than the navigation bar: as a `.searchable`
    /// field it had to collapse on scroll, and that tracking was unreliable
    /// because the section's scroll view sits below this non-scrolling header.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.textSecondary)

            TextField("Search \(section.title.lowercased())", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Palette.card, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.hairline) }
        .padding(.bottom, 4)
        .animation(.smooth(duration: 0.2), value: searchText.isEmpty)
        // Focus once the field is actually in the hierarchy — setting it in the
        // same update as the toggle doesn't take.
        .task { searchFocused = true }
    }

    /// Hiding search also drops the query, so the list is never left filtered by
    /// text the user can't see.
    private func toggleSearch() {
        guard showingSearch else {
            showingSearch = true
            return
        }
        // Dismissing through the responder chain rather than `@FocusState`, which
        // drops the keyboard without animating it. The field stays mounted until
        // the keyboard is down — removing the first responder's view mid-flight
        // also kills the animation.
        searchText = ""
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        #else
        searchFocused = false
        #endif
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            searchFocused = false
            showingSearch = false
        }
    }

    // MARK: - Filter chips

    /// Chips grow out of / shrink into their leading edge so the row reflows
    /// sideways rather than popping.
    private var chipTransition: AnyTransition {
        .scale(scale: 0.8, anchor: .leading).combined(with: .opacity)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filter.genres.sorted(), id: \.self) { genre in
                    FilterChip(label: genre, systemImage: "theatermasks") {
                        filter.toggleGenre(genre)
                    }
                    .transition(chipTransition)
                }
                ForEach(filter.sources.sorted(), id: \.self) { source in
                    FilterChip(label: source, systemImage: "sparkles") {
                        filter.toggleSource(source)
                    }
                    .transition(chipTransition)
                }
                ForEach(filter.locations.sorted(), id: \.self) { location in
                    FilterChip(label: location, systemImage: "play.tv") {
                        filter.toggleLocation(location)
                    }
                    .transition(chipTransition)
                }
                if filter.activeCount > 1 {
                    Button("Clear All") { filter.clear() }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.leading, 2)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 22)
            .animation(.smooth(duration: 0.25), value: filter)
        }
        .padding(.bottom, 16)
    }

    // MARK: - List

    private var list: some View {
        List(selection: $selection) {
            if section == .watched {
                ForEach(watchedMonths, id: \.month) { group in
                    Section {
                        ForEach(group.movies, id: \.persistentModelID) { movie in
                            row(for: movie)
                        }
                    } header: {
                        monthHeader(group.month, count: group.movies.count)
                    }
                }
            } else {
                ForEach(filteredMovies, id: \.persistentModelID) { movie in
                    row(for: movie)
                }
                .onMove(perform: moveHandler)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    /// Watched movies grouped by the month they were watched, newest first.
    /// Movies without a watched date come last, under a `nil` month.
    private var watchedMonths: [(month: Date?, movies: [Movie])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredMovies) { movie in
            movie.dateWatched.flatMap { calendar.dateInterval(of: .month, for: $0)?.start }
        }
        return groups
            .sorted { ($0.key ?? .distantPast) > ($1.key ?? .distantPast) }
            .map { (month: $0.key, movies: $0.value) }
    }

    private func monthHeader(_ month: Date?, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(month?.formatted(.dateTime.month(.wide).year()) ?? String(localized: "No Date"))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(count == 1 ? "1 movie" : "\(count) movies")
                .font(.subheadline)
                .monospacedDigit()
        }
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets())
    }

    @ViewBuilder
    private func row(for movie: Movie) -> some View {
        let selected = movie.persistentModelID == selection?.persistentModelID
        MovieRow(movie: movie, position: position(for: movie), isSelected: selected,
                 showsReleaseDate: section == .upcoming || section == .queue)
            .tag(movie)
            .listRowBackground(Color.clear)
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

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 16)],
                spacing: 18
            ) {
                ForEach(filteredMovies, id: \.persistentModelID) { movie in
                    gridCell(for: movie)
                }
                .reorderable()
            }
            // Drag-to-reorder the queue (only when unfiltered). The move is
            // applied once, on drop.
            .reorderContainer(for: Movie.self, itemID: \.persistentModelID, isEnabled: canReorder) { difference in
                applyReorder(difference)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func gridCell(for movie: Movie) -> some View {
        let selected = movie.persistentModelID == selection?.persistentModelID

        VStack(alignment: .leading, spacing: 6) {
            PosterView(movie: movie, size: .detail, cornerRadius: 10)
                .overlay(alignment: .topLeading) {
                    if let position = position(for: movie) {
                        positionBadge(position)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Palette.accent, lineWidth: selected ? 3 : 0)
                }
                .shadow(color: selected ? Palette.accent.opacity(0.4) : .black.opacity(0.4),
                        radius: selected ? 10 : 5, y: 3)

            Group {
                if section == .queue, movie.isUpcoming {
                    Text("\(Image(systemName: "calendar")) \(movie.title)")
                } else {
                    Text(movie.title)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
            .lineLimit(1)

            if section == .upcoming, movie.isUpcoming, let release = movie.releaseDateShortText {
                Text(release)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = movie }
        .contextMenu { rowMenu(for: movie) }
    }

    /// Applies a grid drag: takes the dragged movies out of the queue and puts
    /// them back, in their current order, before the destination movie (or at
    /// the end).
    private func applyReorder(_ difference: ReorderDifference<PersistentIdentifier, ReorderableSingleCollectionIdentifier>) {
        let moving = Set(difference.sources)
        let moved = movies.filter { moving.contains($0.persistentModelID) }
        var reordered = movies.filter { !moving.contains($0.persistentModelID) }
        let insertAt: Int
        switch difference.destination.position {
        case .before(let id):
            insertAt = reordered.firstIndex { $0.persistentModelID == id } ?? reordered.endIndex
        case .end:
            insertAt = reordered.endIndex
        }
        reordered.insert(contentsOf: moved, at: insertAt)
        MovieActions.reorderQueue(reordered, in: context)
    }

    private func positionBadge(_ position: Int) -> some View {
        Text("\(position)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(.black.opacity(0.6), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.2)) }
            .padding(6)
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
        if movie.status != .maybeLater && appSettings.showsMaybeLater {
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
        if movie.status != .maybeLater && appSettings.showsMaybeLater {
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
        case .discover, .letterboxd, .profile: ""
        }
    }

    private var emptyMessage: String {
        switch section {
        case .queue: "Add something you want to watch."
        case .upcoming: "Movies in your library with a future release date show up here."
        case .watched: "Movies you mark as watched will show up here."
        case .maybeLater: "Park movies here when you're not sure yet."
        case .discover, .letterboxd, .profile: ""
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

    private enum SectionLayout: Hashable {
        case list, grid, calendar

        var systemImage: String {
            switch self {
            case .list: "list.bullet"
            case .grid: "square.grid.2x2"
            case .calendar: "calendar"
            }
        }
    }

    /// The section's layout: its list/grid mode, or its calendar (Upcoming
    /// and Watched only).
    private var sectionLayout: Binding<SectionLayout> {
        Binding {
            showsCalendar ? .calendar : (viewMode == .grid ? .grid : .list)
        } set: { layout in
            if section == .watched {
                watchedCalendar = layout == .calendar
            } else {
                upcomingCalendar = layout == .calendar
            }
            if layout != .calendar {
                viewModeRaw = (layout == .grid ? LibraryViewMode.grid : .list).rawValue
            }
        }
    }

    private var countText: String {
        let count = filteredMovies.count
        return count == 1 ? "1 movie" : "\(count) movies"
    }

    /// Where the view picker and search/filter go: the leading side.
    private var leadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: how the section is shown, then search and filter. The same
        // menu everywhere; Calendar is offered where the section has one.
        ToolbarItem(placement: leadingPlacement) {
            Menu {
                Picker("View", selection: sectionLayout) {
                    Label("List", systemImage: "list.bullet").tag(SectionLayout.list)
                    Label("Grid", systemImage: "square.grid.2x2").tag(SectionLayout.grid)
                    if hasCalendar {
                        Label("Calendar", systemImage: "calendar").tag(SectionLayout.calendar)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("View", systemImage: sectionLayout.wrappedValue.systemImage)
            }
        }
        ToolbarSpacer(.fixed, placement: leadingPlacement)
        ToolbarItem(placement: leadingPlacement) {
            Button {
                toggleSearch()
            } label: {
                Label("Search", systemImage: showingSearch
                      ? "magnifyingglass.circle.fill"
                      : "magnifyingglass")
            }
        }
        if hasFilters {
            ToolbarItem(placement: leadingPlacement) {
                Button {
                    showingFilterPopover = true
                } label: {
                    Label("Filter", systemImage: filter.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease")
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
        }

        // Trailing: the section's own tools, then Add.
        if section == .queue, !filteredMovies.isEmpty {
            ToolbarItem {
                Button {
                    showingPicker = true
                } label: {
                    Label("Pick a Movie", systemImage: "square.stack.3d.forward.dottedline")
                }
            }
            ToolbarSpacer(.fixed)
        }
        if section == .watched, !sectionMovies.isEmpty {
            ToolbarItem {
                Button {
                    showingStats = true
                } label: {
                    Label("Statistics", systemImage: "chart.bar.xaxis")
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
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MovieListColumn(section: .queue, selection: .constant(nil))
    }
    .environment(AppSettings.mock())
    .modelContainer(MovieStore.previewContainer)
}
#endif
