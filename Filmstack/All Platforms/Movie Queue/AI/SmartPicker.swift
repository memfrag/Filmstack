//
//  Filmstack
//

import Foundation
import FoundationModels

/// Picks the movie from a list that best fits a request ("short and funny"),
/// with a one-line reason. Uses Private Cloud Compute for long lists.
enum SmartPicker {

    @Generable
    nonisolated struct Pick {
        @Guide(description: "The number of the chosen movie in the list")
        var number: Int
        @Guide(description: "Why it fits the request in at most eight words, without naming the movie, like 'Slow-burn heist with two screen legends'")
        var reason: String
    }

    struct Result {
        let index: Int
        let reason: String
    }

    static func pick(from movies: [Movie], request: String) async throws -> Result {
        guard let session = FilmstackAI.session(
            preferCloud: movies.count > 25,
            instructions: """
                You help a person choose one movie to watch tonight from their own \
                watchlist. Pick the single best match for what they ask for.
                """
        ) else {
            throw CancellationError()
        }
        let list = movies.enumerated()
            // Overviews only fit the on-device model's context for short lists.
            .map { "\($0.offset + 1). \(movies.count > 15 ? $0.element.briefPromptDescription : $0.element.promptDescription)" }
            .joined(separator: "\n")
        let prompt = "Watchlist:\n\(list)\n\nWhat they're in the mood for: \(request)"
        let pick = try await session.respond(to: prompt, generating: Pick.self).content
        let index = min(max(pick.number - 1, 0), movies.count - 1)
        return Result(index: index, reason: pick.reason)
    }
}
