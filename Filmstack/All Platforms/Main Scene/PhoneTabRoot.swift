//
//  Filmstack
//

#if os(iOS)

import SwiftUI
import AppDesign
import AppRouting

/// `TabView`-based root used on iPhone and on iPad in compact horizontal size class.
///
/// The library sections are the bottom tabs; Discover and Miscellaneous live under
/// a single "Browse" tab as a sectioned list (iOS doesn't section the More tab).
struct PhoneTabRoot: View {

    @Environment(Router<MainRouting>.self) private var router
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.activeSelectable) {
            ForEach(MainRouting.Selectable.visibleLibraryCases(showingMaybeLater: appSettings.showsMaybeLater), id: \.self) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    MovieSectionStack(section: section)
                }
            }
            Tab("Browse", systemImage: "sparkles",
                value: MainRouting.Selectable.discover(.nowPlaying)) {
                BrowseTab()
            }
            Tab("Settings", systemImage: "gearshape", value: MainRouting.Selectable.settings) {
                NavigationStack {
                    SettingsScreen()
                }
            }
        }
        .onChange(of: appSettings.showsMaybeLater) { _, shows in
            if !shows && router.activeSelectable == .maybeLater { router.activeSelectable = .queue }
        }
    }
}

/// The Browse tab: a sectioned list of Discover lists and Miscellaneous sources.
private struct BrowseTab: View {

    private enum Route: Hashable {
        case discover(DiscoverList)
        case letterboxd
    }

    @Environment(AppSettings.self) private var appSettings
    private let discover = DiscoverStore.shared
    private let letterboxd = LetterboxdStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Discover")
                    ForEach(DiscoverList.allCases, id: \.self) { list in
                        NavigationLink(value: Route.discover(list)) {
                            BrowseCard(
                                title: list.title,
                                subtitle: subtitle(for: list),
                                systemImage: list.systemImage,
                                posterURLs: posterURLs(for: list)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    sectionHeader("Miscellaneous")
                        .padding(.top, 12)
                    NavigationLink(value: Route.letterboxd) {
                        BrowseCard(
                            title: "Letterboxd",
                            subtitle: letterboxdSubtitle,
                            systemImage: "film.stack",
                            posterURLs: letterboxdPosterURLs
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .filmWindowBackground()
            .navigationTitle("Browse")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .discover(let list):
                    DiscoverListContent(list: list)
                case .letterboxd:
                    LetterboxdContent()
                }
            }
            .task { await loadPreviews() }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 4)
    }

    // MARK: - Previews

    /// Loads every list (from today's cache when there is one) and the
    /// Letterboxd diary, so the cards can show posters.
    private func loadPreviews() async {
        await withTaskGroup(of: Void.self) { group in
            for list in DiscoverList.allCases {
                group.addTask { await discover.ensureLoaded(list, region: appSettings.releaseRegion) }
            }
            let username = appSettings.letterboxdUsername
            if !username.isEmpty {
                group.addTask { await letterboxd.ensureLoaded(username: username) }
            }
        }
    }

    private func posterURLs(for list: DiscoverList) -> [URL] {
        guard case .loaded(let movies) = discover.phase(for: list) else { return [] }
        return movies.prefix(4).compactMap { TMDBImage.posterURL(path: $0.posterPath, size: .queue) }
    }

    private func subtitle(for list: DiscoverList) -> String {
        switch discover.phase(for: list) {
        case .loaded(let movies):
            movies.count == 1 ? String(localized: "1 movie") : String(localized: "\(movies.count) movies")
        case .loading, .idle:
            String(localized: "Loading…")
        case .failed:
            String(localized: "Couldn't load")
        }
    }

    private var letterboxdPosterURLs: [URL] {
        guard case .loaded(let entries) = letterboxd.phase else { return [] }
        return entries.prefix(4).compactMap(\.posterURL)
    }

    private var letterboxdSubtitle: String {
        let username = appSettings.letterboxdUsername
        guard !username.isEmpty else { return String(localized: "Connect your diary") }
        return String(localized: "\(username)'s diary")
    }
}

/// A Discover list and its detail push, without its own navigation stack (it's
/// pushed inside the Browse stack).
private struct DiscoverListContent: View {

    let list: DiscoverList
    @State private var selection: BrowseSelection?

    var body: some View {
        DiscoverColumn(list: list, selection: $selection)
            .navigationDestination(item: $selection) { selection in
                DiscoverDetailColumn(selection: selection)
                    .navigationTitle(selection.result.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
    }
}

private struct LetterboxdContent: View {

    @State private var selection: BrowseSelection?

    var body: some View {
        LetterboxdColumn(selection: $selection)
            .navigationDestination(item: $selection) { selection in
                DiscoverDetailColumn(selection: selection)
                    .navigationTitle(selection.result.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
    }
}

/// A library section wrapped in a navigation stack, pushing detail on selection.
private struct MovieSectionStack: View {

    let section: MainRouting.Selectable
    @State private var selectedMovie: Movie?

    var body: some View {
        NavigationStack {
            MovieListColumn(section: section, selection: $selectedMovie)
                .navigationDestination(item: $selectedMovie) { movie in
                    MovieDetailColumn(selection: $selectedMovie)
                        .navigationTitle("" /*movie.title*/)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
    }
}

#if DEBUG
#Preview {
    PhoneTabRoot()
        .appEnvironment(.mock())
        .modelContainer(MovieStore.previewContainer)
}
#endif

#endif
