//
//  Filmstack
//

#if os(iOS)

import SwiftUI
import AppDesign
import AppRouting

/// `TabView`-based root used on iPhone and on iPad in compact horizontal size class.
///
/// Each tab is a library section that pushes the movie detail onto its own
/// navigation stack.
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
            Tab("Discover", systemImage: "sparkles", value: .discover(.nowPlaying)) {
                DiscoverTabStack()
            }
            Tab("Letterboxd", systemImage: "film.stack", value: .letterboxd) {
                LetterboxdTabStack()
            }
        }
    }
}

/// iPhone Letterboxd tab: a navigation stack pushing detail on selection.
private struct LetterboxdTabStack: View {

    @State private var selection: BrowseSelection?

    var body: some View {
        NavigationStack {
            LetterboxdColumn(selection: $selection)
                .navigationDestination(item: $selection) { selection in
                    DiscoverDetailColumn(selection: selection)
                        .navigationTitle(selection.result.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
    }
}

/// iPhone Discover tab: a navigation stack with a picker to switch lists.
private struct DiscoverTabStack: View {

    @State private var list: DiscoverList = .nowPlaying
    @State private var selection: BrowseSelection?

    var body: some View {
        NavigationStack {
            DiscoverColumn(list: list, selection: $selection)
                .id(list)
                .navigationDestination(item: $selection) { selection in
                    DiscoverDetailColumn(selection: selection)
                        .navigationTitle(selection.result.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("List", selection: $list) {
                            ForEach(DiscoverList.allCases, id: \.self) { list in
                                Text(list.title).tag(list)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
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
                        .navigationTitle(movie.title)
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
