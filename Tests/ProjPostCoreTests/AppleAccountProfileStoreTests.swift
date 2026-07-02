import XCTest
@testable import ProjPostCore

final class AppleAccountProfileStoreTests: XCTestCase {
    func testSaveAndLoadProfiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let fileSystem = LocalFileSystem()
        try fileSystem.createDirectory(root)
        let store = AppleAccountProfileStore(fileURL: root.appendingPathComponent("accounts.json"), fileSystem: fileSystem)
        let profile = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: Date(timeIntervalSince1970: 123)
        )

        try store.save([profile])

        XCTAssertEqual(try store.load(), [profile])
    }

    func testMissingStoreFileLoadsEmptyArray() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = AppleAccountProfileStore(fileURL: root.appendingPathComponent("accounts.json"), fileSystem: LocalFileSystem())

        XCTAssertEqual(try store.load(), [])
    }
}
