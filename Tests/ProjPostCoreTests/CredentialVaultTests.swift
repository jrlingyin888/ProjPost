import Foundation
import Security
import XCTest
@testable import ProjPostCore

final class CredentialVaultTests: XCTestCase {
    func testSavePrivateKeyAddsNewItemWithoutDeleting() throws {
        let client = FakeKeychainClient()
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        try vault.savePrivateKey("new-key", for: accountID)

        XCTAssertEqual(client.calls, [.add])
        XCTAssertEqual(client.items[accountID.uuidString]?.textValue, "new-key")
        XCTAssertEqual(client.lastAddedAttributes?[kSecAttrService as String] as? String, "test.service")
        XCTAssertEqual(
            client.lastAddedAttributes?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
    }

    func testSavePrivateKeyUpdatesExistingItemWhenAddFindsDuplicate() throws {
        let client = FakeKeychainClient()
        client.items[accountID.uuidString] = .utf8("old-key")
        client.addStatus = errSecDuplicateItem
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        try vault.savePrivateKey("updated-key", for: accountID)

        XCTAssertEqual(client.calls, [.add, .update])
        XCTAssertEqual(client.items[accountID.uuidString]?.textValue, "updated-key")
        XCTAssertEqual(client.lastUpdateQuery?[kSecAttrAccount as String] as? String, accountID.uuidString)
        XCTAssertEqual(
            client.lastUpdatedAttributes?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
    }

    func testSavePrivateKeyThrowsAndPreservesExistingItemWhenUpdateFails() throws {
        let client = FakeKeychainClient()
        client.items[accountID.uuidString] = .utf8("old-key")
        client.addStatus = errSecDuplicateItem
        client.updateStatus = errSecAuthFailed
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        XCTAssertThrowsError(try vault.savePrivateKey("replacement-key", for: accountID)) { error in
            XCTAssertEqual(error as? CredentialVaultError, .keychainStatus(errSecAuthFailed))
        }
        XCTAssertEqual(client.calls, [.add, .update])
        XCTAssertEqual(client.items[accountID.uuidString]?.textValue, "old-key")
    }

    func testPrivateKeyReturnsStoredValue() throws {
        let client = FakeKeychainClient()
        client.items[accountID.uuidString] = .utf8("stored-key")
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        let privateKey = try vault.privateKey(for: accountID)

        XCTAssertEqual(privateKey, "stored-key")
        XCTAssertEqual(client.calls, [.copyMatching])
        XCTAssertEqual(client.lastCopyMatchingQuery?[kSecReturnData as String] as? Bool, true)
    }

    func testPrivateKeyExistsChecksAttributesWithoutReturningSecretData() throws {
        let client = FakeKeychainClient()
        client.items[accountID.uuidString] = .utf8("stored-key")
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        let exists = try vault.privateKeyExists(for: accountID)

        XCTAssertTrue(exists)
        XCTAssertEqual(client.calls, [.copyMatching])
        XCTAssertNil(client.lastCopyMatchingQuery?[kSecReturnData as String])
        XCTAssertEqual(client.lastCopyMatchingQuery?[kSecReturnAttributes as String] as? Bool, true)
    }

    func testPrivateKeyExistsReturnsFalseWhenItemIsMissing() throws {
        let client = FakeKeychainClient()
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        let exists = try vault.privateKeyExists(for: accountID)

        XCTAssertFalse(exists)
    }

    func testPrivateKeyThrowsItemNotFound() throws {
        let client = FakeKeychainClient()
        client.copyMatchingStatus = errSecItemNotFound
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        XCTAssertThrowsError(try vault.privateKey(for: accountID)) { error in
            XCTAssertEqual(error as? CredentialVaultError, .itemNotFound)
        }
    }

    func testPrivateKeyThrowsInvalidDataWhenStoredValueIsNotUTF8() throws {
        let client = FakeKeychainClient()
        client.items[accountID.uuidString] = .raw(Data([0xFF]))
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        XCTAssertThrowsError(try vault.privateKey(for: accountID)) { error in
            XCTAssertEqual(error as? CredentialVaultError, .invalidData)
        }
    }

    func testDeletePrivateKeyRemovesStoredValue() throws {
        let client = FakeKeychainClient()
        client.items[accountID.uuidString] = .utf8("stored-key")
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        try vault.deletePrivateKey(for: accountID)

        XCTAssertNil(client.items[accountID.uuidString])
        XCTAssertEqual(client.calls, [.delete])
    }

    func testDeletePrivateKeyIgnoresMissingItem() throws {
        let client = FakeKeychainClient()
        client.deleteStatusWhenMissing = errSecItemNotFound
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        XCTAssertNoThrow(try vault.deletePrivateKey(for: accountID))
        XCTAssertEqual(client.calls, [.delete])
    }

    func testDeletePrivateKeyThrowsKeychainError() throws {
        let client = FakeKeychainClient()
        client.deleteStatusWhenMissing = errSecInteractionNotAllowed
        let vault = KeychainCredentialVault(service: "test.service", keychain: client)

        XCTAssertThrowsError(try vault.deletePrivateKey(for: accountID)) { error in
            XCTAssertEqual(error as? CredentialVaultError, .keychainStatus(errSecInteractionNotAllowed))
        }
    }

    private let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
}

private final class FakeKeychainClient: KeychainClient {
    enum Call: Equatable {
        case add
        case update
        case copyMatching
        case delete
    }

    enum StoredValue: Equatable {
        case raw(Data)

        static func utf8(_ string: String) -> StoredValue {
            .raw(Data(string.utf8))
        }

        var data: Data {
            switch self {
            case let .raw(data):
                return data
            }
        }

        var textValue: String? {
            String(data: data, encoding: .utf8)
        }
    }

    var addStatus: OSStatus = errSecSuccess
    var updateStatus: OSStatus = errSecSuccess
    var copyMatchingStatus: OSStatus = errSecSuccess
    var deleteStatusWhenMissing: OSStatus = errSecSuccess
    var items: [String: StoredValue] = [:]
    var calls: [Call] = []
    var lastAddedAttributes: [String: Any]?
    var lastUpdateQuery: [String: Any]?
    var lastUpdatedAttributes: [String: Any]?
    var lastCopyMatchingQuery: [String: Any]?

    func add(_ attributes: [String: Any]) -> OSStatus {
        calls.append(.add)
        lastAddedAttributes = attributes

        guard addStatus == errSecSuccess else {
            return addStatus
        }

        guard let account = attributes[kSecAttrAccount as String] as? String,
              let data = attributes[kSecValueData as String] as? Data else {
            return errSecParam
        }

        if items[account] != nil {
            return errSecDuplicateItem
        }

        items[account] = .raw(data)
        return errSecSuccess
    }

    func update(query: [String: Any], attributesToUpdate: [String: Any]) -> OSStatus {
        calls.append(.update)
        lastUpdateQuery = query
        lastUpdatedAttributes = attributesToUpdate

        guard updateStatus == errSecSuccess else {
            return updateStatus
        }

        guard let account = query[kSecAttrAccount as String] as? String,
              items[account] != nil,
              let data = attributesToUpdate[kSecValueData as String] as? Data else {
            return errSecItemNotFound
        }

        items[account] = .raw(data)
        return errSecSuccess
    }

    func copyMatching(_ query: [String: Any], result: inout AnyObject?) -> OSStatus {
        calls.append(.copyMatching)
        lastCopyMatchingQuery = query

        guard copyMatchingStatus == errSecSuccess else {
            return copyMatchingStatus
        }

        guard let account = query[kSecAttrAccount as String] as? String,
              let value = items[account] else {
            return errSecItemNotFound
        }

        if query[kSecReturnData as String] as? Bool == true {
            result = value.data as AnyObject
        } else if query[kSecReturnAttributes as String] as? Bool == true {
            result = [
                kSecAttrAccount as String: account,
                kSecAttrService as String: query[kSecAttrService as String] as? String ?? ""
            ] as CFDictionary
        }
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        calls.append(.delete)

        guard let account = query[kSecAttrAccount as String] as? String else {
            return errSecParam
        }

        guard items.removeValue(forKey: account) != nil else {
            return deleteStatusWhenMissing
        }

        return errSecSuccess
    }
}
