import XCTest
@testable import ProjPostCore

final class ProjectMutatorTests: XCTestCase {
    func testPlanFromProjectProfileIncludesBackupAndReadableSummary() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let info = projectRoot.appendingPathComponent("Demo/Info.plist")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path, info.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let project = ProjectProfile(
            name: "Demo",
            projectPath: projectRoot.path,
            workspacePath: nil,
            projectFilePath: projectRoot.appendingPathComponent("Demo.xcodeproj").path,
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.old.demo",
            version: "1.0.0",
            buildNumber: "1",
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )

        let plan = try mutator.plan(
            project: project,
            targetBundleID: "com.example.demo",
            targetVersion: "1.0.1",
            targetBuildNumber: "2",
            infoPlistURL: info
        )

        XCTAssertEqual(plan.changes.map(\.summary), [
            "Bundle ID: com.old.demo -> com.example.demo",
            "Version: 1.0.0 -> 1.0.1",
            "Build Number: 1 -> 2"
        ])
        XCTAssertEqual(plan.filesToBackup, [pbxproj, info])
    }

    func testPlanThrowsWhenTargetVersionExistsButCurrentVersionIsMissing() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let project = ProjectProfile(
            name: "Demo",
            projectPath: projectRoot.path,
            workspacePath: nil,
            projectFilePath: projectRoot.appendingPathComponent("Demo.xcodeproj").path,
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.old.demo",
            version: nil,
            buildNumber: "1",
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )

        XCTAssertThrowsError(
            try mutator.plan(
                project: project,
                targetBundleID: nil,
                targetVersion: "1.0.1",
                targetBuildNumber: nil,
                infoPlistURL: nil
            )
        ) { error in
            guard case ProjectMutatorError.missingCurrentValue(let label) = error else {
                return XCTFail("Expected missingCurrentValue, got \(error)")
            }

            XCTAssertEqual(label, "Version")
        }
    }

    func testPlansCreatedBackToBackUseDistinctBackupDirectories() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let request = ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: pbxproj,
            infoPlistURL: nil,
            currentBundleID: "com.old.demo",
            newBundleID: "com.example.demo",
            currentVersion: "1.0.0",
            newVersion: "1.0.1",
            currentBuildNumber: "1",
            newBuildNumber: "2"
        )

        let firstPlan = try mutator.plan(request: request)
        let secondPlan = try mutator.plan(request: request)

        XCTAssertNotEqual(firstPlan.backupDirectory, secondPlan.backupDirectory)
        XCTAssertTrue(firstPlan.backupDirectory.lastPathComponent.hasPrefix("202"))
        XCTAssertTrue(secondPlan.backupDirectory.lastPathComponent.hasPrefix("202"))
    }

    func testApplyThrowsWhenExpectedBundleIDSettingIsMissing() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let fileSystem = RecordingFileSystem(
            existingFiles: [pbxproj.path],
            dataByURL: [
                pbxproj: Data("MARKETING_VERSION = 1.0.0;\nCURRENT_PROJECT_VERSION = 1;".utf8)
            ]
        )
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let request = ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: pbxproj,
            infoPlistURL: nil,
            currentBundleID: "com.old.demo",
            newBundleID: "com.example.demo",
            currentVersion: "1.0.0",
            newVersion: "1.0.1",
            currentBuildNumber: "1",
            newBuildNumber: "2"
        )

        let plan = try mutator.plan(request: request)

        XCTAssertThrowsError(try mutator.apply(plan)) { error in
            guard case ProjectMutatorError.expectedSettingNotFound(let setting) = error else {
                return XCTFail("Expected expectedSettingNotFound, got \(error)")
            }

            XCTAssertEqual(setting, "PRODUCT_BUNDLE_IDENTIFIER = com.old.demo;")
        }
        XCTAssertNil(fileSystem.written[pbxproj])
    }
}

private final class RecordingFileSystem: FileSysteming {
    let existingFiles: Set<String>
    let dataByURL: [URL: Data]
    var written: [URL: Data] = [:]

    init(existingFiles: [String], dataByURL: [URL: Data] = [:]) {
        self.existingFiles = Set(existingFiles)
        self.dataByURL = dataByURL
    }

    func fileExists(_ url: URL) -> Bool { existingFiles.contains(url.path) }
    func contentsOfDirectory(_ url: URL) throws -> [String] { [] }
    func createDirectory(_ url: URL) throws {}
    func readData(_ url: URL) throws -> Data { dataByURL[url] ?? Data("PRODUCT_BUNDLE_IDENTIFIER = com.old.demo;".utf8) }
    func writeData(_ data: Data, to url: URL) throws { written[url] = data }
    func removeItem(_ url: URL) throws {}
}
