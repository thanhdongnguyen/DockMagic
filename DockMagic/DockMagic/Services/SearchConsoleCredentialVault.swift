import Foundation
import Security

protocol SearchConsoleCredentialVault: Sendable {
    func store(privateKey: String, reference: String) throws
    func load(reference: String) throws -> String?
    func delete(reference: String) throws
}

enum SearchConsoleCredentialVaultError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "macOS Keychain returned error \(status)."
        case .invalidEncoding:
            return "The private key stored in macOS Keychain is not valid UTF-8."
        }
    }
}

struct KeychainSearchConsoleCredentialVault: SearchConsoleCredentialVault {
    static let service = "com.hypevibe.DockMagic.search-console"

    func store(privateKey: String, reference: String) throws {
        let data = Data(privateKey.utf8)
        let query = baseQuery(reference: reference)
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw SearchConsoleCredentialVaultError.unexpectedStatus(updateStatus)
            }
        case errSecItemNotFound:
            var addition = query
            addition[kSecValueData as String] = data
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addition as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SearchConsoleCredentialVaultError.unexpectedStatus(addStatus)
            }
        default:
            throw SearchConsoleCredentialVaultError.unexpectedStatus(status)
        }
    }

    func load(reference: String) throws -> String? {
        var query = baseQuery(reference: reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SearchConsoleCredentialVaultError.unexpectedStatus(status)
        }
        guard let data = result as? Data,
              let privateKey = String(data: data, encoding: .utf8) else {
            throw SearchConsoleCredentialVaultError.invalidEncoding
        }
        return privateKey
    }

    func delete(reference: String) throws {
        let status = SecItemDelete(baseQuery(reference: reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SearchConsoleCredentialVaultError.unexpectedStatus(status)
        }
    }

    private func baseQuery(reference: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: reference
        ]
    }
}

final class InMemorySearchConsoleCredentialVault:
    SearchConsoleCredentialVault, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func store(privateKey: String, reference: String) throws {
        lock.withLock { values[reference] = privateKey }
    }

    func load(reference: String) throws -> String? {
        lock.withLock { values[reference] }
    }

    func delete(reference: String) throws {
        _ = lock.withLock { values.removeValue(forKey: reference) }
    }
}
