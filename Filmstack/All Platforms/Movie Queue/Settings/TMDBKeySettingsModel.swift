//
//  Filmstack
//

import Foundation

/// Drives the TMDB API key settings screen: reports the stored-key status and
/// validates/saves/deletes the token via the Keychain store and API client.
@MainActor
@Observable
final class TMDBKeySettingsModel {

    enum Status: Equatable {
        case missing
        case configured(masked: String)
        case invalid
    }

    struct Feedback: Equatable {
        enum Kind { case success, error }
        var kind: Kind
        var text: String
    }

    /// Bound to the token entry field.
    var tokenInput: String = ""

    private(set) var status: Status = .missing
    private(set) var isBusy = false
    private(set) var feedback: Feedback?

    private let keyStore: any APIKeyStore
    private let client: any MovieAPIClient

    init(
        keyStore: any APIKeyStore = AppEnvironment.default.apiKeyStore,
        client: any MovieAPIClient = AppEnvironment.default.movieAPIClient
    ) {
        self.keyStore = keyStore
        self.client = client
        refreshStatus()
    }

    var isConfigured: Bool {
        if case .configured = status { return true }
        return false
    }

    var canSave: Bool {
        !tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    // MARK: - Actions

    func refreshStatus() {
        do {
            if let token = try keyStore.loadTMDBToken(), !token.isEmpty {
                status = .configured(masked: Self.mask(token))
            } else {
                status = .missing
            }
        } catch {
            status = .missing
            feedback = .init(kind: .error, text: Self.message(for: error))
        }
    }

    /// Validates the entered token against TMDB and, only if valid, saves it to the
    /// Keychain. Invalid tokens are never stored.
    func saveToken() async {
        let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        isBusy = true
        feedback = nil
        defer { isBusy = false }

        do {
            guard try await client.validateToken(token) else {
                status = .invalid
                feedback = .init(kind: .error, text: TMDBError.invalidToken.message)
                return
            }
            try keyStore.saveTMDBToken(token)
            tokenInput = ""
            refreshStatus()
            feedback = .init(kind: .success, text: "TMDB key saved.")
        } catch {
            feedback = .init(kind: .error, text: Self.message(for: error))
        }
    }

    func testConnection() async {
        isBusy = true
        feedback = nil
        defer { isBusy = false }

        do {
            guard let token = try keyStore.loadTMDBToken(), !token.isEmpty else {
                feedback = .init(kind: .error, text: TMDBError.missingAPIKey.message)
                return
            }
            if try await client.validateToken(token) {
                feedback = .init(kind: .success, text: "Connection OK.")
            } else {
                status = .invalid
                feedback = .init(kind: .error, text: TMDBError.invalidToken.message)
            }
        } catch {
            feedback = .init(kind: .error, text: Self.message(for: error))
        }
    }

    func deleteToken() {
        do {
            try keyStore.deleteTMDBToken()
            tokenInput = ""
            refreshStatus()
            feedback = .init(kind: .success, text: "TMDB key deleted.")
        } catch {
            feedback = .init(kind: .error, text: Self.message(for: error))
        }
    }

    // MARK: - Helpers

    private static func mask(_ token: String) -> String {
        let suffix = token.suffix(4)
        return suffix.isEmpty ? "configured" : "••••••••••••\(suffix)"
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private extension TMDBError {
    /// Non-optional convenience for user-facing copy.
    var message: String { errorDescription ?? "Something went wrong talking to TMDB." }
}
