//
//  Filmstack
//

import Foundation
import FoundationModels

/// Writes the body of a release-day reminder on the device, drawing on the
/// user's own notes about the movie. Results are kept for the session so
/// rescheduling doesn't ask the model again.
enum ReminderWriter {

    private static var cache: [String: String] = [:]

    /// A one-line reminder for `title`, or nil when no model is available or
    /// it fails (callers fall back to fixed text).
    static func line(title: String, notes: String, overview: String?) async -> String? {
        let key = "\(title)|\(notes)"
        if let cached = cache[key] { return cached }
        guard FilmstackAI.isDeviceAvailable,
              let session = FilmstackAI.session(instructions: """
                  You write one short, friendly notification line (under 110 \
                  characters) telling someone a movie they've been waiting for is \
                  out today. Work in why they wanted to see it, from their own note. \
                  Write to them in the second person. No emoji, no quotes, no hashtags.
                  """)
        else { return nil }

        var prompt = "Movie: \(title)\nTheir note: \(notes)"
        if let overview, !overview.isEmpty {
            prompt += "\nAbout the movie: \(overview.prefix(300))"
        }
        guard let line = try? await session.respond(to: prompt).content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”")),
              !line.isEmpty, line.count <= 180
        else { return nil }
        cache[key] = line
        return line
    }
}
