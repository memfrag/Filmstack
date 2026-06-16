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
            Tab(MovieStatus.queued.title, systemImage: MovieStatus.queued.systemImage, value: .queue) {
                MovieSectionStack(status: .queued)
            }
            Tab(MovieStatus.watched.title, systemImage: MovieStatus.watched.systemImage, value: .watched) {
                MovieSectionStack(status: .watched)
            }
            Tab(MovieStatus.maybeLater.title, systemImage: MovieStatus.maybeLater.systemImage, value: .maybeLater) {
                MovieSectionStack(status: .maybeLater)
            }
        }
    }
}

/// A library section wrapped in a navigation stack, pushing detail on selection.
private struct MovieSectionStack: View {

    let status: MovieStatus
    @State private var selectedMovie: Movie?

    var body: some View {
        NavigationStack {
            MovieListColumn(status: status, selection: $selectedMovie)
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
