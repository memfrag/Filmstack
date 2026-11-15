//
//  Filmstack
//

import Foundation
import FoundationModels
import OSLog

/// Access to Apple's language models for Filmstack's AI features.
///
/// Small, private tasks (tagging, search, reminders) run on the on-device
/// model. Tasks that need more reasoning (recommendations, the year summary)
/// prefer Private Cloud Compute and fall back to the device. Every AI control
/// in the app is hidden when no model is available.
enum FilmstackAI {

    /// The on-device model.
    static var deviceModel: SystemLanguageModel { .default }

    /// Whether the app has the managed `com.apple.developer.private-cloud-compute`
    /// entitlement (in `Filmstack.entitlements`). Private Cloud Compute stops
    /// the app with a fatal error without it, so builds that drop the
    /// entitlement must set this to false.
    static let hasCloudEntitlement = true

    /// Apple's Private Cloud Compute model.
    static let cloudModel = PrivateCloudComputeLanguageModel()

    static var isDeviceAvailable: Bool { deviceModel.isAvailable }
    static var isCloudAvailable: Bool {
        hasCloudEntitlement && cloudModel.availability == .available
    }

    /// Whether any model can run.
    static var isAvailable: Bool { isDeviceAvailable || isCloudAvailable }

    /// Whether some model can look at images.
    static var canSeeImages: Bool {
        (isDeviceAvailable && deviceModel.capabilities.contains(.vision))
            || (isCloudAvailable && cloudModel.capabilities.contains(.vision))
    }

    /// A new session. `preferCloud` uses Private Cloud Compute when it's
    /// available; otherwise the on-device model, then whichever is left.
    static func session(preferCloud: Bool = false, instructions: String) -> LanguageModelSession? {
        if preferCloud, isCloudAvailable {
            return LanguageModelSession(model: cloudModel, instructions: instructions)
        }
        if isDeviceAvailable {
            return LanguageModelSession(model: deviceModel, instructions: instructions)
        }
        if isCloudAvailable {
            return LanguageModelSession(model: cloudModel, instructions: instructions)
        }
        return nil
    }

    /// Asks for structured output, trying each available model in turn:
    /// Private Cloud Compute first when `preferCloud` (it can still refuse a
    /// request, say offline or in the simulator), then the device.
    static func respond<Content: Generable>(
        preferCloud: Bool, instructions: String, to prompt: String, generating type: Content.Type
    ) async throws -> Content {
        var models: [(name: String, session: () -> LanguageModelSession)] = []
        if preferCloud, isCloudAvailable {
            models.append(("cloud", { LanguageModelSession(model: cloudModel, instructions: instructions) }))
        }
        if isDeviceAvailable {
            models.append(("device", { LanguageModelSession(model: deviceModel, instructions: instructions) }))
        }
        if !preferCloud, isCloudAvailable {
            models.append(("cloud", { LanguageModelSession(model: cloudModel, instructions: instructions) }))
        }
        guard !models.isEmpty else { throw CancellationError() }

        var lastError: Error = CancellationError()
        for model in models {
            do {
                return try await model.session().respond(to: prompt, generating: type).content
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("\(model.name, privacy: .public) model failed: \(String(describing: error), privacy: .public)")
                lastError = error
            }
        }
        throw lastError
    }

    private static let logger = Logger(subsystem: "io.apparata.Filmstack", category: "AI")

    /// A session on a model that can see images, device first.
    static func visionSession(instructions: String) -> LanguageModelSession? {
        if isDeviceAvailable, deviceModel.capabilities.contains(.vision) {
            return LanguageModelSession(model: deviceModel, instructions: instructions)
        }
        if isCloudAvailable, cloudModel.capabilities.contains(.vision) {
            return LanguageModelSession(model: cloudModel, instructions: instructions)
        }
        return nil
    }

    /// The English name of a language code ("ko" → "Korean"), for prompts.
    nonisolated static func languageName(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return Locale(identifier: "en").localizedString(forLanguageCode: code)
    }

    // MARK: - Status

    /// Whether a model is ready, for the status shown in Profile.
    struct Status {
        let isReady: Bool
        let text: String
        /// Still getting ready on its own (the model is downloading).
        var isInProgress = false
    }

    /// The on-device model's state, with the reason when it can't run.
    static var deviceStatus: Status {
        switch deviceModel.availability {
        case .available:
            return Status(isReady: true, text: String(localized: "Ready"))
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return Status(isReady: false, text: String(localized: "Turned off in Settings"))
            case .modelNotReady:
                return Status(isReady: false, text: String(localized: "Downloading"), isInProgress: true)
            case .deviceNotEligible:
                return Status(isReady: false, text: String(localized: "Not supported on this device"))
            @unknown default:
                return Status(isReady: false, text: String(localized: "Unavailable"))
            }
        }
    }

    /// Private Cloud Compute's state.
    static var cloudStatus: Status {
        guard hasCloudEntitlement else {
            return Status(isReady: false, text: String(localized: "Not enabled in this build"))
        }
        switch cloudModel.availability {
        case .available:
            return Status(isReady: true, text: String(localized: "Ready"))
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return Status(isReady: false, text: String(localized: "Not supported on this device"))
            case .systemNotReady:
                return Status(isReady: false, text: String(localized: "Not ready yet"))
            @unknown default:
                return Status(isReady: false, text: String(localized: "Unavailable"))
            }
        }
    }

    /// A user-facing message for a failed request.
    static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return String(localized: "Apple Intelligence couldn't answer right now. Try again.")
    }
}

// MARK: - Moods

/// The fixed set of moods movies are tagged with. A fixed vocabulary keeps the
/// mood filter short and consistent across the library.
@Generable
nonisolated enum Mood: String, CaseIterable, Codable, Sendable {
    case cozy, funny, heartwarming, romantic, uplifting, thoughtful
    case tense, dark, scary, mindBending, epic, actionPacked

    var title: String {
        switch self {
        case .cozy: String(localized: "Cozy")
        case .funny: String(localized: "Funny")
        case .heartwarming: String(localized: "Heartwarming")
        case .romantic: String(localized: "Romantic")
        case .uplifting: String(localized: "Uplifting")
        case .thoughtful: String(localized: "Thoughtful")
        case .tense: String(localized: "Tense")
        case .dark: String(localized: "Dark")
        case .scary: String(localized: "Scary")
        case .mindBending: String(localized: "Mind-Bending")
        case .epic: String(localized: "Epic")
        case .actionPacked: String(localized: "Action-Packed")
        }
    }

    /// The title for a stored raw value, or the raw value itself.
    static func title(for rawValue: String) -> String {
        Mood(rawValue: rawValue)?.title ?? rawValue
    }
}

// MARK: - Prompt text

extension Movie {

    /// One line describing the movie for a prompt.
    var promptDescription: String {
        var parts = [briefPromptDescription]
        if let tagline { parts.append("\"\(tagline)\"") }
        if let overview, !overview.isEmpty { parts.append(String(overview.prefix(220))) }
        return parts.joined(separator: " | ")
    }

    /// The prompt line without the overview, for prompts covering many movies.
    var briefPromptDescription: String {
        var parts = [title]
        if let year = releaseYear { parts[0] += " (\(year))" }
        if !genres.isEmpty { parts.append(genres.joined(separator: ", ")) }
        if let runtime = runtimeMinutes { parts.append("\(runtime) min") }
        if let director { parts.append("dir. " + director) }
        if !cast.isEmpty { parts.append("with " + cast.prefix(2).joined(separator: ", ")) }
        if let language = FilmstackAI.languageName(originalLanguage) { parts.append("in " + language) }
        if let certification { parts.append("rated " + certification) }
        if !keywords.isEmpty { parts.append("keywords: " + keywords.prefix(6).joined(separator: ", ")) }
        if !moodTags.isEmpty { parts.append("moods: " + moodTags.map(Mood.title(for:)).joined(separator: ", ")) }
        return parts.joined(separator: " | ")
    }
}
