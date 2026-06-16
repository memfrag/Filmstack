//
//  Filmstack
//

import Foundation
import SwiftData

/// Mutations on the movie library. These keep queue positions contiguous and
/// timestamps current, and persist immediately.
@MainActor
enum MovieActions {

    // MARK: - Adding

    /// Appends a new movie to the bottom of the queue.
    static func addToQueue(_ movie: Movie, in context: ModelContext) {
        movie.status = .queued
        movie.queuePosition = (maxQueuePosition(in: context) ?? -1) + 1
        movie.dateAdded = Date()
        touch(movie)
        context.insert(movie)
        save(context)
    }

    /// Inserts a new movie, honouring its `status`. Queued movies are appended to
    /// the bottom of the queue; others are inserted as-is.
    static func add(_ movie: Movie, in context: ModelContext) {
        if movie.status == .queued {
            addToQueue(movie, in: context)
        } else {
            movie.queuePosition = nil
            touch(movie)
            context.insert(movie)
            save(context)
        }
    }

    /// Inserts a new movie at the top of the queue, shifting the rest down.
    static func addToTop(_ movie: Movie, in context: ModelContext) {
        for existing in queuedMovies(in: context) {
            existing.queuePosition = (existing.queuePosition ?? 0) + 1
        }
        movie.status = .queued
        movie.queuePosition = 0
        movie.dateAdded = Date()
        touch(movie)
        context.insert(movie)
        save(context)
    }

    // MARK: - Status changes

    static func markWatched(_ movie: Movie, in context: ModelContext) {
        movie.status = .watched
        movie.dateWatched = Date()
        movie.queuePosition = nil
        touch(movie)
        renumberQueue(in: context)
        save(context)
    }

    static func moveBackToQueue(_ movie: Movie, in context: ModelContext) {
        movie.status = .queued
        movie.dateWatched = nil
        movie.queuePosition = (maxQueuePosition(in: context) ?? -1) + 1
        touch(movie)
        save(context)
    }

    // MARK: - Reordering

    static func moveToTop(_ movie: Movie, in context: ModelContext) {
        var queue = queuedMovies(in: context).filter { $0.persistentModelID != movie.persistentModelID }
        queue.insert(movie, at: 0)
        applyOrder(queue)
        save(context)
    }

    static func moveToBottom(_ movie: Movie, in context: ModelContext) {
        var queue = queuedMovies(in: context).filter { $0.persistentModelID != movie.persistentModelID }
        queue.append(movie)
        applyOrder(queue)
        save(context)
    }

    /// Persists a new order for the queue (e.g. from a drag-and-drop `onMove`).
    static func reorderQueue(_ orderedMovies: [Movie], in context: ModelContext) {
        applyOrder(orderedMovies)
        save(context)
    }

    /// Reassigns contiguous positions `0..<n` to the queued movies, in their
    /// current order.
    static func renumberQueue(in context: ModelContext) {
        applyOrder(queuedMovies(in: context))
    }

    // MARK: - Deleting

    static func delete(_ movie: Movie, in context: ModelContext) {
        let wasQueued = movie.status == .queued
        context.delete(movie)
        if wasQueued {
            renumberQueue(in: context)
        }
        save(context)
    }

    // MARK: - Editing

    static func save(edited movie: Movie, in context: ModelContext) {
        touch(movie)
        save(context)
    }

    // MARK: - Helpers

    static func queuedMovies(in context: ModelContext) -> [Movie] {
        let queued = MovieStatus.queued.rawValue
        let descriptor = FetchDescriptor<Movie>(
            predicate: #Predicate { $0.statusRawValue == queued },
            sortBy: [SortDescriptor(\.queuePosition, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func maxQueuePosition(in context: ModelContext) -> Int? {
        queuedMovies(in: context).compactMap(\.queuePosition).max()
    }

    private static func applyOrder(_ movies: [Movie]) {
        for (index, movie) in movies.enumerated() {
            movie.queuePosition = index
            touch(movie)
        }
    }

    private static func touch(_ movie: Movie) {
        movie.updatedAt = Date()
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            // Persistence failures are surfaced via the UI layer later; for now,
            // avoid crashing and keep the in-memory state usable.
            assertionFailure("Failed to save movie changes: \(error)")
        }
    }
}
