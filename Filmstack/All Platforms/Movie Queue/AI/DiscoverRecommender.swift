//
//  Filmstack
//

import Foundation
import FoundationModels

/// Ranks a Discover list against the movies the user rated highly, with a
/// short "why you might like it" for each pick. Prefers Private Cloud Compute.
enum DiscoverRecommender {

    @Generable
    nonisolated struct Recommendation {
        @Guide(description: "The number of the recommended movie in the candidate list")
        var number: Int
        @Guide(description: "Why this person might like it, in at most five words, referring to their taste, like 'Twisty like Heat'")
        var reason: String
    }

    @Generable
    nonisolated struct Recommendations {
        @Guide(description: "The best matches for this person's taste, best first", .count(3...8))
        var picks: [Recommendation]
    }

    enum RecommendError: LocalizedError {
        case noTaste

        var errorDescription: String? {
            String(localized: "Rate a few movies you've watched first, so there's something to go on.")
        }
    }

    /// TMDB IDs of the picks, best first, with reasons.
    static func recommend(from candidates: [MovieSearchResult], library: [Movie]) async throws -> [(tmdbID: Int, reason: String)] {
        // Up to 15 of the best-rated watched movies describe the taste.
        let favorites = library
            .filter { $0.status == .watched && ($0.userRating ?? 0) >= 3.5 }
            .sorted { ($0.userRating ?? 0) > ($1.userRating ?? 0) }
            .prefix(15)
        guard !favorites.isEmpty else { throw RecommendError.noTaste }

        let owned = Set(library.compactMap(\.tmdbID))
        let pool = Array(candidates.filter { !owned.contains($0.tmdbID) }.prefix(30))
        guard !pool.isEmpty else { return [] }

        let preferCloud = true
        let instructions = """
                You recommend movies. Given movies a person loved and a list of \
                candidates, pick the candidates they're most likely to enjoy.
                """

        let taste = favorites
            .map { "- \($0.briefPromptDescription) — rated \($0.userRating.map { String(format: "%.1f", $0) } ?? "?")/5" }
            .joined(separator: "\n")
        let list = pool.enumerated()
            .map { index, movie in
                var line = "\(index + 1). \(movie.title)"
                if let year = movie.releaseYear { line += " (\(year))" }
                if let genres = movie.genres, !genres.isEmpty { line += " | " + genres.joined(separator: ", ") }
                if let rating = movie.tmdbRating { line += " | TMDB \(String(format: "%.1f", rating))/10" }
                if let overview = movie.overview, !overview.isEmpty { line += " | " + overview.prefix(150) }
                return line
            }
            .joined(separator: "\n")
        let prompt = "Movies they loved:\n\(taste)\n\nCandidates:\n\(list)"

        let result = try await FilmstackAI.respond(preferCloud: preferCloud, instructions: instructions,
                                                to: prompt, generating: Recommendations.self)
        var seen = Set<Int>()
        return result.picks.compactMap { pick in
            guard pool.indices.contains(pick.number - 1) else { return nil }
            let id = pool[pick.number - 1].tmdbID
            guard seen.insert(id).inserted else { return nil }
            return (id, pick.reason)
        }
    }
}
