//
//  Filmstack
//

import Foundation

/// Drives TMDB search for the Add Movie sheet.
///
/// Debouncing and stale-request cancellation are handled by the view via
/// `.task(id:)`; this model performs a single search per call and reports the
/// resulting phase.
@MainActor
@Observable
final class MovieSearchModel {

    enum Phase: Equatable {
        case idle
        case noToken
        case searching
        case results([MovieSearchResult])
        case empty
        case failed(String)
    }

    var query: String = ""
    private(set) var phase: Phase

    private let client: any MovieAPIClient
    private let keyStore: any APIKeyStore

    init(
        client: any MovieAPIClient = AppEnvironment.default.movieAPIClient,
        keyStore: any APIKeyStore = AppEnvironment.default.apiKeyStore
    ) {
        self.client = client
        self.keyStore = keyStore
        self.phase = keyStore.hasTMDBToken ? .idle : .noToken
    }

    var hasToken: Bool { keyStore.hasTMDBToken }

    /// Minimum characters before a search is issued (per spec).
    static let minimumQueryLength = 2

    func search() async {
        guard hasToken else {
            phase = .noToken
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumQueryLength else {
            phase = .idle
            return
        }

        phase = .searching
        do {
            let results = try await client.searchMovies(query: trimmed)
            guard !Task.isCancelled else { return }
            phase = results.isEmpty ? .empty : .results(results)
        } catch is CancellationError {
            // Superseded by a newer query; leave the newer task to set state.
        } catch let error as URLError where error.code == .cancelled {
            // Superseded request.
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(Self.message(for: error))
        }
    }

    func fetchDetails(for result: MovieSearchResult) async throws -> MovieDetails {
        try await client.fetchMovieDetails(tmdbID: result.tmdbID)
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
