//
//  Filmstack
//

import Foundation

/// Loads and caches TMDB Discover lists. Each list is refreshed at most once per
/// calendar day; results are persisted to disk so the cache survives relaunches.
@MainActor
@Observable
final class DiscoverStore {

    static let shared = DiscoverStore()

    enum Phase: Equatable {
        case idle
        case loading
        case loaded([MovieSearchResult])
        case failed(String)
    }

    private(set) var phases: [DiscoverList: Phase] = [:]
    private var fetchedDay: [DiscoverList: Date] = [:]

    private let client: any MovieAPIClient

    init(client: any MovieAPIClient = AppEnvironment.default.movieAPIClient) {
        self.client = client
        loadFromDisk()
    }

    func phase(for list: DiscoverList) -> Phase {
        phases[list] ?? .idle
    }

    /// Loads the list, reusing today's cache when present.
    func ensureLoaded(_ list: DiscoverList, region: String?) async {
        if let day = fetchedDay[list], Calendar.current.isDateInToday(day),
           case .loaded = phases[list] {
            return
        }
        await refresh(list, region: region)
    }

    /// Forces a fresh fetch regardless of the cache.
    func refresh(_ list: DiscoverList, region: String?) async {
        phases[list] = .loading
        do {
            let movies = try await client.fetchDiscover(list: list, region: region)
            phases[list] = .loaded(movies)
            fetchedDay[list] = Calendar.current.startOfDay(for: Date())
            saveToDisk()
        } catch {
            phases[list] = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: - Persistence

    private struct DiskEntry: Codable {
        var day: Date
        var movies: [MovieSearchResult]
    }

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("discover-cache.json")
    }

    private func loadFromDisk() {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: DiskEntry].self, from: data)
        else { return }

        for (key, entry) in entries {
            guard let list = DiscoverList(rawValue: key) else { continue }
            fetchedDay[list] = entry.day
            phases[list] = .loaded(entry.movies)
        }
    }

    private func saveToDisk() {
        guard let url = cacheURL else { return }
        var entries: [String: DiskEntry] = [:]
        for (list, day) in fetchedDay {
            if case .loaded(let movies) = phases[list] {
                entries[list.rawValue] = DiskEntry(day: day, movies: movies)
            }
        }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url)
        }
    }
}
