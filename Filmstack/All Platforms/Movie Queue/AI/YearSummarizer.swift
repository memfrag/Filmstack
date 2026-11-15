//
//  Filmstack
//

import Foundation
import FoundationModels

/// Writes the words around a year's recap: a short headline and a sentence
/// or two. Every number and fact shown on the recap comes from
/// `WatchedStats.YearFacts`; the model is told those facts and asked not to
/// use numbers, and any sentence that still contains one is dropped, so the
/// text can't contradict the statistics. Prefers Private Cloud Compute.
enum YearSummarizer {

    @Generable
    nonisolated struct Recap {
        @Guide(description: "A creative two-to-six word title for their year in movies, like 'The Year of the Blockbuster', with no numbers")
        var headline: String
        @Guide(description: "One or two sentences to them in the second person about what their year was like, with no numbers or digits")
        var summary: String
    }

    /// A written recap, kept per year with the facts it was written from.
    struct Written: Codable, Equatable, Sendable {
        let headline: String
        let summary: String?
        /// `YearFacts.signature` at the time of writing.
        let signature: String
    }

    static func write(facts: WatchedStats.YearFacts, entries: [WatchedEntry]) async throws -> Written {
        let preferCloud = true
        let instructions = """
                You title someone's year in movies, warmly and specifically, \
                speaking to them in the second person. Use only the facts and \
                titles you're given; never invent movies, people, genres or \
                habits, and never write numbers or digits.
                """

        var lines = ["Year: \(facts.year)"]
        if let genre = facts.favoriteGenre { lines.append("Favorite genre: \(genre.name)") }
        if let month = facts.busiestMonth {
            lines.append("Busiest month: \(month.start.formatted(.dateTime.month(.wide)))")
        }
        if let top = facts.topRated { lines.append("Highest rated: \(top.title)") }
        if let director = facts.topDirector { lines.append("Most watched director: \(director.name)") }
        if let mood = facts.topMood { lines.append("Most common mood: \(Mood.title(for: mood.name))") }
        let titles = entries
            .prefix(60)  // keeps the prompt inside the on-device model's context
            .map { entry in
                entry.genres.isEmpty ? entry.title : "\(entry.title) (\(entry.genres.prefix(2).joined(separator: ", ")))"
            }
            .joined(separator: "; ")
        lines.append("Movies watched: \(titles)")

        let recap = try await FilmstackAI.respond(preferCloud: preferCloud, instructions: instructions,
                                                to: lines.joined(separator: "\n"), generating: Recap.self)
        return Written(
            headline: cleanHeadline(recap.headline),
            summary: cleanSummary(recap.summary),
            signature: facts.signature
        )
    }

    // MARK: - Validation

    /// Drops quotes and a trailing full stop; falls back when the model
    /// slipped a number in.
    static func cleanHeadline(_ text: String) -> String {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'."))
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isNumber), trimmed.count <= 60 else {
            return String(localized: "Your Year in Movies")
        }
        return trimmed
    }

    /// Keeps at most two sentences, leaving out any with a number in it.
    static func cleanSummary(_ text: String) -> String? {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            guard let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sentence.isEmpty, !sentence.contains(where: \.isNumber) else { return }
            sentences.append(sentence)
        }
        let kept = sentences.prefix(2).joined(separator: " ")
        return kept.isEmpty ? nil : kept
    }

    // MARK: - Cache

    private static func cacheKey(_ year: Int) -> String { "filmstack.yearRecap.\(year)" }

    /// The saved recap for a year, if it was written from the same facts.
    static func cached(for facts: WatchedStats.YearFacts) -> Written? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(facts.year)),
              let written = try? JSONDecoder().decode(Written.self, from: data),
              written.signature == facts.signature
        else { return nil }
        return written
    }

    static func save(_ written: Written, year: Int) {
        if let data = try? JSONEncoder().encode(written) {
            UserDefaults.standard.set(data, forKey: cacheKey(year))
        }
    }
}
