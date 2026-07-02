import XCTest
@testable import ProjPostCore

final class ProjectMutatorTests: XCTestCase {
    func testPlanIncludesBackupAndReadableSummary() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let info = projectRoot.appendingPathComponent("Demo/Info.plist")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path, info.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let request = ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: pbxproj,
            infoPlistURL: info,
            currentBundleID: "com.old.demo",
            newBundleID: "com.example.demo",
            currentVersion: "1.0.0",
            newVersion: "1.0.1",
            currentBuildNumber: "1",
            newBuildNumber: "2"
        )

        let plan = try mutator.plan(request: request)

        XCTAssertEqual(plan.changes.map(\.summary), [
            "Bundle ID: com.old.demo -> com.example.demo",
            "Version: 1.0.0 -> 1.0.1",
            "Build Number: 1 -> 2"
        ])
        XCTAssertEqual(plan.filesToBackup, [pbxproj, info])
    }
}

private final class RecordingFileSystem: FileSysteming {
    let existingFiles: Set<String>
    var written: [URL: Data] = [:]

    init(existingFiles: [String]) {
        self.existingFiles = Set(existingFiles)
    }

    func fileExists(_ url: URL) -> Bool { existingFiles.contains(url.path) }
    func contentsOfDirectory(_ url: URL) throws -> [String] { [] }
    func createDirectory(_ url: URL) throws {}
    func readData(_ url: URL) throws -> Data { Data("PRODUCT_BUNDLE_IDENTIFIER = com.old.demo;".utf8) }
    func writeData(_ data: Data, to url: URL) throws { written[url] = data }
}
