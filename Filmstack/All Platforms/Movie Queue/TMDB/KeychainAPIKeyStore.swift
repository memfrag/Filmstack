//
//  Filmstack
//

import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            return "Keychain error: \(message)"
        case .dataConversionFailed:
            return "Could not read the API key from Keychain."
        }
    }
}

/// Keychain-backed `APIKeyStore` for the TMDB Read Access Token.
///
/// Stored as a generic password keyed by `service` + `account`. Accessible only on
/// this device after first unlock, and never synced.
final class KeychainAPIKeyStore: APIKeyStore {

    private let service: String
    private let account: String

    init(
        service: String = "\(Bundle.main.bundleIdentifier ?? "io.apparata.Filmstack").tmdb",
        account: String = "tmdb-read-access-token"
    ) {
        self.service = service
        self.account = account
    }

    func saveTMDBToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // Replace any existing item so save is idempotent.
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func loadTMDBToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return token
    }

    func deleteTMDBToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
