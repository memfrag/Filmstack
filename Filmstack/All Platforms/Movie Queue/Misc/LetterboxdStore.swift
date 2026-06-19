//
//  Filmstack
//

import Foundation

/// Loads and caches a Letterboxd user's diary RSS feed.
@MainActor
@Observable
final class LetterboxdStore {

    static let shared = LetterboxdStore()

    enum Phase: Equatable {
        case idle
        case loading
        case loaded([LetterboxdEntry])
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var loadedUsername: String?

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Loads the feed for `username`, reusing the result if already loaded.
    func ensureLoaded(username: String) async {
        let normalized = Self.normalize(username)
        guard !normalized.isEmpty else {
            phase = .idle
            return
        }
        if loadedUsername == normalized, case .loaded = phase { return }
        await refresh(username: normalized)
    }

    /// Forces a fresh fetch.
    func refresh(username: String) async {
        let normalized = Self.normalize(username)
        guard !normalized.isEmpty else {
            phase = .idle
            return
        }
        guard let url = URL(string: "https://letterboxd.com/\(normalized)/rss/") else {
            phase = .failed("Invalid username.")
            return
        }

        phase = .loading
        do {
            var request = URLRequest(url: url)
            // Letterboxd serves the feed only to browser-like clients.
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                phase = .failed("No Letterboxd account found for '\(normalized)'.")
                return
            }
            // Parse off the main actor — feeds can be large enough to jank the UI.
            let entries = await Task.detached(priority: .userInitiated) {
                LetterboxdRSSParser.parse(data)
                    .sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
            }.value
            loadedUsername = normalized
            phase = .loaded(entries)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private static func normalize(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
