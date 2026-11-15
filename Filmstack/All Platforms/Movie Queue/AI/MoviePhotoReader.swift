//
//  Filmstack
//

import Foundation
import CoreGraphics
import ImageIO
import FoundationModels
import Vision

/// Works out which movie a photo shows (a poster, a cinema listing, a TV
/// screen) with a model that can see images.
enum MoviePhotoReader {

    @Generable
    nonisolated struct SpottedMovie {
        @Guide(description: "The title of the movie shown, as it's usually written; empty if no movie can be identified")
        var title: String
        @Guide(description: "The release year if it's shown or obvious; otherwise nil")
        var year: Int?
    }

    enum ReadError: LocalizedError {
        case unreadableImage, noMovie

        var errorDescription: String? {
            switch self {
            case .unreadableImage: String(localized: "That image couldn't be read.")
            case .noMovie: String(localized: "No movie could be recognized in that photo.")
            }
        }
    }

    /// The movie title (and year, when known) in the image data.
    static func read(_ imageData: Data) async throws -> SpottedMovie {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1536,
              ] as CFDictionary)
        else { throw ReadError.unreadableImage }

        guard let session = FilmstackAI.visionSession(instructions: """
            You identify movies from photos of posters, cinema listings, tickets \
            or screens.
            """) else {
            throw CancellationError()
        }
        // The model reads small or stylised lettering poorly, so give it the
        // text Vision finds too, largest (most likely the title) first.
        let text = await recognizedText(in: image)
        let prompt = text.isEmpty
            ? "Which movie is this photo about?"
            : """
              Which movie is this photo about? Text found in the photo, largest \
              first: \(text.joined(separator: " | "))
              """
        let spotted = try await session.respond(generating: SpottedMovie.self) {
            prompt
            Attachment(image)
        }.content
        guard !spotted.title.trimmingCharacters(in: .whitespaces).isEmpty else { throw ReadError.noMovie }
        return spotted
    }

    /// Lines of text in the image, largest lettering first (at most 12).
    private static func recognizedText(in image: CGImage) async -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        guard let observations = try? await request.perform(on: image) else { return [] }
        return observations
            .sorted { $0.boundingBox.height > $1.boundingBox.height }
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { $0.count > 1 }
            .prefix(12)
            .map { $0 }
    }
}
