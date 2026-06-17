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
    /// Selection is remembered per library section, so switching sections and
    /// returning preserves what was selected.
    @State private var selections: [MainRouting.Selectable: Movie] = [:]

    var body: some View {
        @Bindable var router = router

        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $router.activeSelectable)
        } content: {
            MovieListColumn(
                status: router.activeSelectable.movieStatus,
                selection: selectionBinding
            )
            .id(router.activeSelectable)
        } detail: {
            MovieDetailColumn(selection: selectionBinding)
                .ignoresSafeArea(edges: .top)
        }
        .toolbar(removing: .title)
    }

    private var selectionBinding: Binding<Movie?> {
        Binding(
            get: { selections[router.activeSelectable] },
            set: { selections[router.activeSelectable] = $0 }
        )
    }
}

#Preview {
    SplitRoot()
        .appEnvironment(.mock())
        .modelContainer(MovieStore.previewContainer)
}
