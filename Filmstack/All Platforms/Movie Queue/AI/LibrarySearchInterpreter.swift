//
//  Filmstack
//

import Foundation
import FoundationModels

/// Turns a plain-language request ("Korean thrillers under two hours") into
/// library filters, using the on-device model.
enum LibrarySearchInterpreter {

    @Generable
    nonisolated struct Intent {
        @Guide(description: "Genres the user asks for, chosen only from the provided list; empty if none")
        var genres: [String]
        @Guide(description: "Moods that match the request; empty if the request doesn't describe a feeling")
        var moods: [Mood]
        @Guide(description: "Maximum runtime in minutes if the user limits length, for example 'under two hours' is 120; otherwise nil")
        var maxRuntimeMinutes: Int?
        @Guide(description: "Earliest release year if the user limits it, for example 'from the nineties' is 1990; otherwise nil")
        var earliestYear: Int?
        @Guide(description: "Latest release year if the user limits it, for example 'from the nineties' is 1999; otherwise nil")
        var latestYear: Int?
        @Guide(description: "Text to match in movie titles, only if the user names a specific title or word in one; otherwise empty")
        var titleText: String
    }

    struct Result {
        var filter: LibraryFilter
        var titleText: String
    }

    /// Interprets `query`. Genres are limited to `availableGenres` (matched
    /// case-insensitively) and moods to `availableMoods`.
    static func interpret(
        _ query: String,
        availableGenres: [String],
        availableMoods: [String]
    ) async throws -> Result {
        guard let session = FilmstackAI.session(instructions: """
            You turn a person's request for movies into search filters for their \
            personal movie library. Only fill in what the request actually asks for.
            """) else {
            throw CancellationError()
        }
        let prompt = """
            Available genres: \(availableGenres.joined(separator: ", ")).
            Request: \(query)
            """
        let intent = try await session.respond(to: prompt, generating: Intent.self).content

        var filter = LibraryFilter()
        let lookup = Dictionary(availableGenres.map { ($0.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        filter.genres = Set(intent.genres.compactMap { lookup[$0.lowercased()] })
        filter.moods = Set(intent.moods.map(\.rawValue)).intersection(availableMoods)
        // The model sometimes fills in limits nobody asked for; keep them only
        // when the request talks about length or time.
        let words = query.lowercased()
        if mentionsLength(words) {
            filter.maxRuntimeMinutes = intent.maxRuntimeMinutes.flatMap { $0 > 0 ? $0 : nil }
        }
        if mentionsYears(words) {
            filter.minYear = intent.earliestYear
            filter.maxYear = intent.latestYear
        }
        return Result(filter: filter, titleText: intent.titleText.trimmingCharacters(in: .whitespaces))
    }

    private static func mentionsLength(_ query: String) -> Bool {
        ["hour", "min", "short", "long", "quick", "length", "runtime"].contains { query.contains($0) }
    }

    private static func mentionsYears(_ query: String) -> Bool {
        query.contains(where: \.isNumber)
            || ["ties", "decade", "century", "year", "recent", "new", "old", "classic", "release"]
                .contains { query.contains($0) }
    }
}
