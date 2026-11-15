//
//  Filmstack
//

import Foundation
import FoundationModels

/// Writes a short, personal "your year in movies" recap from what was watched
/// in a year: a one-line headline and a few highlights. Prefers Private
/// Cloud Compute.
enum YearSummarizer {

    @Generable
    nonisolated struct Recap: Equatable {
        @Guide(description: "One sentence that sums up their year in movies, to them in the second person")
        var headline: String
        @Guide(description: "Short, specific highlights, each one sentence of at most 15 words, like 'Dramas made up most of your year' or 'You gave Spirited Away your top rating'", .count(3...5))
        var highlights: [String]
    }

    static func summary(of movies: [Movie], year: Int) async throws -> Recap {
        guard let session = FilmstackAI.session(
            preferCloud: true,
            instructions: """
                You write a warm, specific recap of someone's year in movies, \
                written to them in the second person, in normally capitalized \
                sentences without emoji. Point out patterns: favorite genres, \
                moods or directors, busy stretches, standout ratings, and name \
                a few titles. Don't invent anything that isn't in the data.
                """
        ) else {
            throw CancellationError()
        }

        let lines = movies
            .sorted { ($0.dateWatched ?? .distantPast) < ($1.dateWatched ?? .distantPast) }
            // Keeps the prompt inside the on-device model's context.
            .prefix(80)
            .map { movie in
                var line = movie.briefPromptDescription
                if let date = movie.dateWatched {
                    line = date.formatted(.dateTime.month(.wide)) + ": " + line
                }
                if let rating = movie.userRating {
                    line += " | rated \(String(format: "%.1f", rating))/5"
                }
                return line
            }
            .joined(separator: "\n")
        let prompt = "Movies watched in \(year), in order:\n\(lines)"
        return try await session.respond(to: prompt, generating: Recap.self).content
    }
}
