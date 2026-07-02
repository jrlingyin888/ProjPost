import Foundation
import Security

protocol KeychainClient {
    func add(_ attributes: [String: Any]) -> OSStatus
    func update(query: [String: Any], attributesToUpdate: [String: Any]) -> OSStatus
    func copyMatching(_ query: [String: Any], result: inout AnyObject?) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

struct SystemKeychainClient: KeychainClient {
    func add(_ attributes: [String: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func update(query: [String: Any], attributesToUpdate: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
    }

    func copyMatching(_ query: [String: Any], result: inout AnyObject?) -> OSStatus {
        SecItemCopyMatching(query as CFDictionary, &result)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

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
    private let service: String
    private let keychain: KeychainClient

    init(service: String, keychain: KeychainClient) {
        self.service = service
        self.keychain = keychain
    }

    public convenience init() {
        self.init(service: "com.projpost.appstoreconnect", keychain: SystemKeychainClient())
    }

    public func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws {
        let account = accountID.uuidString
        let data = Data(privateKeyPEM.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = keychain.add(item)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let updateStatus = keychain.update(query: query, attributesToUpdate: attributesToUpdate)
            guard updateStatus == errSecSuccess else {
                throw CredentialVaultError.keychainStatus(updateStatus)
            }
        default:
            throw CredentialVaultError.keychainStatus(addStatus)
        }
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
        let status = keychain.copyMatching(query, result: &result)
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

        let status = keychain.delete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialVaultError.keychainStatus(status)
        }
    }
}
