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
    @State private var discoverSelection: BrowseSelection?

    var body: some View {
        @Bindable var router = router

        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $router.activeSelectable)
        } content: {
            Group {
                if let list = router.activeSelectable.discoverList {
                    DiscoverColumn(list: list, selection: $discoverSelection)
                } else if router.activeSelectable == .letterboxd {
                    LetterboxdColumn(selection: $discoverSelection)
                } else {
                    MovieListColumn(
                        section: router.activeSelectable,
                        selection: selectionBinding
                    )
                }
            }
            .id(router.activeSelectable)
        } detail: {
            detailColumn
                .ignoresSafeArea(edges: .top)
        }
        .toolbar(removing: .title)
        #if os(macOS)
        .toolbarBackground(.clear, for: .windowToolbar)
        #endif
        .onChange(of: router.activeSelectable) { discoverSelection = nil }
    }

    @ViewBuilder private var detailColumn: some View {
        if router.activeSelectable.isExternalBrowse {
            if let result = discoverSelection {
                DiscoverDetailColumn(selection: result)
            } else {
                discoverEmptyState
            }
        } else {
            MovieDetailColumn(selection: selectionBinding)
        }
    }

    private var discoverEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.8))
            Text("Discover Movies")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            Text("Select a movie to see details and add it to your library.")
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.base)
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
