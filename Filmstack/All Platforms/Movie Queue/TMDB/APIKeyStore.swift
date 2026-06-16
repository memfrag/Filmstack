//
//  Filmstack
//

import Foundation

/// Stores the user's TMDB Read Access Token.
///
/// The token is a credential and must only ever live in the Keychain — never in
/// `UserDefaults`, SwiftData, or logs.
protocol APIKeyStore: Sendable {
    func saveTMDBToken(_ token: String) throws
    func loadTMDBToken() throws -> String?
    func deleteTMDBToken() throws
}

extension APIKeyStore {
    /// Whether a non-empty token is currently stored.
    var hasTMDBToken: Bool {
        ((try? loadTMDBToken()) ?? nil)?.isEmpty == false
    }
}
