//
//  Filmstack
//

import SwiftUI
import SwiftData
import FoundationModels
import OSLog

/// Tags library movies with moods in the background, using the on-device
/// model's content-tagging mode. Each movie is tagged once; tags feed the mood
/// filter.
struct MoodTaggerModifier: ViewModifier {

    @Environment(\.modelContext) private var context

    /// Movies not tagged yet.
    @Query(filter: #Predicate<Movie> { $0.moodsTaggedAt == nil })
    private var untagged: [Movie]

    func body(content: Content) -> some View {
        content
            // Keyed on "anything to do?" rather than the count, so tagging a
            // movie doesn't restart (and cancel) the run.
            .task(id: untagged.isEmpty) {
                await tagAll()
            }
    }

    private static let logger = Logger(subsystem: "io.apparata.Filmstack", category: "AI")

    @Generable
    nonisolated struct MoodTagging {
        @Guide(description: "The one to three moods that best describe watching this movie", .count(1...3))
        var moods: [Mood]
    }

    /// Tags every untagged movie, one at a time, including movies added while
    /// it runs. Stops at the first failure that isn't specific to one movie,
    /// leaving the rest for next time.
    private func tagAll() async {
        guard FilmstackAI.isDeviceAvailable else { return }
        // The content-tagging mode isn't installed everywhere; fall back to
        // the general on-device model when it fails.
        var models = [SystemLanguageModel(useCase: .contentTagging), SystemLanguageModel.default]

        // Re-fetch after each pass: movies added meanwhile don't restart the
        // task (it's keyed on whether any are untagged), so pick them up here.
        let descriptor = FetchDescriptor<Movie>(predicate: #Predicate { $0.moodsTaggedAt == nil })
        while let batch = try? context.fetch(descriptor), !batch.isEmpty {
            for movie in batch {
                guard !Task.isCancelled else { return }
                guard let overview = movie.overview, !overview.isEmpty else {
                    movie.moodsTaggedAt = Date()  // nothing to go on
                    continue
                }
                var prompt = "\(movie.title). Genres: \(movie.genres.joined(separator: ", "))."
                if !movie.keywords.isEmpty { prompt += " Keywords: \(movie.keywords.joined(separator: ", "))." }
                if let tagline = movie.tagline { prompt += " Tagline: \(tagline)" }
                prompt += " \(overview)"
                var tagged = false
                while let model = models.first, !tagged {
                    let session = LanguageModelSession(
                        model: model,
                        instructions: "Tag movies with the moods a viewer would feel watching them."
                    )
                    do {
                        let result = try await session.respond(to: prompt, generating: MoodTagging.self)
                        movie.moodTags = Array(Set(result.content.moods.map(\.rawValue))).sorted()
                        movie.moodsTaggedAt = Date()
                        tagged = true
                    } catch is CancellationError {
                        return
                    } catch {
                        Self.logger.error("Mood tagging failed: \(String(describing: error), privacy: .public)")
                        models.removeFirst()
                    }
                }
                guard tagged else {
                    try? context.save()
                    return
                }
                try? context.save()
            }
        }
        try? context.save()
    }
}

extension View {
    /// Tags library movies with moods in the background.
    func moodTagging() -> some View {
        modifier(MoodTaggerModifier())
    }
}
