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

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.activeSelectable) {
            ForEach(MainRouting.Selectable.libraryCases, id: \.self) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    MovieSectionStack(section: section)
                }
            }
            Tab("Browse", systemImage: "sparkles",
                value: MainRouting.Selectable.discover(.nowPlaying)) {
                BrowseTab()
            }
        }
    }
}

/// The Browse tab: a sectioned list of Discover lists and Miscellaneous sources.
private struct BrowseTab: View {

    private enum Route: Hashable {
        case discover(DiscoverList)
        case letterboxd
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Discover") {
                    ForEach(DiscoverList.allCases, id: \.self) { list in
                        NavigationLink(value: Route.discover(list)) {
                            Label(list.title, systemImage: list.systemImage)
                        }
                    }
                }
                Section("Miscellaneous") {
                    NavigationLink(value: Route.letterboxd) {
                        Label("Letterboxd", systemImage: "film.stack")
                    }
                }
            }
            .navigationTitle("Browse")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .discover(let list):
                    DiscoverListContent(list: list)
                case .letterboxd:
                    LetterboxdContent()
                }
            }
        }
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

#Preview {
    PhoneTabRoot()
        .appEnvironment(.mock())
        .modelContainer(MovieStore.previewContainer)
}

#endif
