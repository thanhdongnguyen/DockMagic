import Foundation
import Security

protocol GitHubCredentialVault: Sendable {
    func storeAccessToken(_ token: String) throws
    func loadAccessToken() throws -> String?
    func deleteAccessToken() throws
}

enum GitHubCredentialVaultError: LocalizedError, Equatable {
    case emptyToken
    case tokenContainsWhitespace
    case unexpectedStatus(OSStatus)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            return "Enter a GitHub access token."
        case .tokenContainsWhitespace:
            return "GitHub access tokens cannot contain whitespace."
        case let .unexpectedStatus(status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "macOS Keychain returned error \(status)."
        case .invalidEncoding:
            return "The GitHub token stored in macOS Keychain is not valid UTF-8."
        }
    }
}

struct KeychainGitHubCredentialVault: GitHubCredentialVault {
    static let service = "com.hypevibe.DockMagic.github"
    static let account = "github.access-token"

    private let service: String
    private let account: String

    init(
        service: String = Self.service,
        account: String = Self.account
    ) {
        self.service = service
        self.account = account
    }

    func storeAccessToken(_ token: String) throws {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw GitHubCredentialVaultError.emptyToken
        }
        guard !normalized.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            throw GitHubCredentialVaultError.tokenContainsWhitespace
        }

        let data = Data(normalized.utf8)
        let query = baseQuery
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw GitHubCredentialVaultError.unexpectedStatus(updateStatus)
            }
        case errSecItemNotFound:
            var addition = query
            addition[kSecValueData as String] = data
            addition[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addition as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw GitHubCredentialVaultError.unexpectedStatus(addStatus)
            }
        default:
            throw GitHubCredentialVaultError.unexpectedStatus(status)
        }
    }

    func loadAccessToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw GitHubCredentialVaultError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw GitHubCredentialVaultError.invalidEncoding
        }
        return token
    }

    func deleteAccessToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitHubCredentialVaultError.unexpectedStatus(status)
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

final class InMemoryGitHubCredentialVault:
    GitHubCredentialVault,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func storeAccessToken(_ token: String) throws {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw GitHubCredentialVaultError.emptyToken
        }
        guard !normalized.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            throw GitHubCredentialVaultError.tokenContainsWhitespace
        }
        lock.withLock { self.token = normalized }
    }

    func loadAccessToken() throws -> String? {
        lock.withLock { token }
    }

    func deleteAccessToken() throws {
        lock.withLock { token = nil }
    }
}
