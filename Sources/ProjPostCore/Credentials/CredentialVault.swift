import Foundation
import Security

public protocol CredentialVault {
    func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws
    func privateKey(for accountID: UUID) throws -> String
    func deletePrivateKey(for accountID: UUID) throws
}

public enum CredentialVaultError: Error, Equatable {
    case itemNotFound
    case invalidData
    case keychainStatus(OSStatus)
}

public final class KeychainCredentialVault: CredentialVault {
    private let service = "com.projpost.appstoreconnect"

    public init() {}

    public func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws {
        let account = accountID.uuidString
        let data = Data(privateKeyPEM.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialVaultError.keychainStatus(status) }
    }

    public func privateKey(for accountID: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { throw CredentialVaultError.itemNotFound }
        guard status == errSecSuccess else { throw CredentialVaultError.keychainStatus(status) }
        guard let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
            throw CredentialVaultError.invalidData
        }

        return text
    }

    public func deletePrivateKey(for accountID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialVaultError.keychainStatus(status)
        }
    }
}
