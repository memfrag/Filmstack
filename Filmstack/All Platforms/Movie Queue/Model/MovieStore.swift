//
//  Filmstack
//

import Foundation
import SwiftData

/// Central place to construct the SwiftData stack for movies.
enum MovieStore {

    /// All persisted model types.
    static let schema = Schema([Movie.self])

    /// The on-disk container used by the running app.
    @MainActor
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create Movie ModelContainer: \(error)")
        }
    }

    #if DEBUG
    /// An in-memory container pre-populated with sample movies, for previews.
    @MainActor
    static var previewContainer: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            SampleMovies.seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
    #endif
}
