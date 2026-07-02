import XCTest
@testable import ProjPostCore

final class ProjectProfileStoreTests: XCTestCase {
    func testSaveAndLoadProfiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let fileSystem = LocalFileSystem()
        try fileSystem.createDirectory(root)
        let store = ProjectProfileStore(fileURL: root.appendingPathComponent("projects.json"), fileSystem: fileSystem)

        let profile = ProjectProfile(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Demo",
            projectPath: "/tmp/Demo",
            workspacePath: nil,
            projectFilePath: "/tmp/Demo/Demo.xcodeproj",
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.example.demo",
            version: "1.0.0",
            buildNumber: "1",
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )

        try store.save([profile])

        XCTAssertEqual(try store.load(), [profile])
    }

    func testMissingStoreFileLoadsEmptyArray() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = ProjectProfileStore(fileURL: root.appendingPathComponent("projects.json"), fileSystem: LocalFileSystem())

        XCTAssertEqual(try store.load(), [])
    }
}
