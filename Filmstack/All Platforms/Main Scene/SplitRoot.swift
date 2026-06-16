//
//  Filmstack
//

import SwiftUI
import AppDesign
import AppRouting

/// Three-column `NavigationSplitView` root used on iPad (regular width), macOS, and
/// visionOS: sidebar (library sections) → movie list → movie detail.
///
/// Shares the `Router<MainRouting>.activeSelectable` selection with `PhoneTabRoot`,
/// so the selected library section persists across iPad compact↔regular transitions.
struct SplitRoot: View {

    @Environment(Router<MainRouting>.self) private var router

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedMovie: Movie?

    var body: some View {
        @Bindable var router = router

        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $router.activeSelectable)
        } content: {
            MovieListColumn(status: router.activeSelectable.movieStatus, selection: $selectedMovie)
                .id(router.activeSelectable)
        } detail: {
            MovieDetailColumn(selection: $selectedMovie)
        }
        .onChange(of: router.activeSelectable) {
            selectedMovie = nil
        }
    }
}

#Preview {
    SplitRoot()
        .appEnvironment(.mock())
        .modelContainer(MovieStore.previewContainer)
}
