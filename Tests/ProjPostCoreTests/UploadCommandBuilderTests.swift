import XCTest
@testable import ProjPostCore

final class UploadCommandBuilderTests: XCTestCase {
    func testArchiveCommandUsesWorkspaceSchemeAndReleaseConfiguration() throws {
        let project = ProjectProfile(
            name: "Demo",
            projectPath: "/tmp/Demo",
            workspacePath: "/tmp/Demo/Demo.xcworkspace",
            projectFilePath: nil,
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.example.demo",
            version: "1.0.0",
            buildNumber: "1",
            teamID: "ABCDE12345",
            selectedAccountID: nil,
            lastUpload: nil
        )
        let builder = UploadCommandBuilder()

        let command = try builder.archiveCommand(project: project, archivePath: URL(fileURLWithPath: "/tmp/Demo/build/Demo.xcarchive"))

        XCTAssertEqual(command.executableURL.path, "/usr/bin/xcodebuild")
        XCTAssertEqual(command.arguments, [
            "archive",
            "-workspace", "/tmp/Demo/Demo.xcworkspace",
            "-scheme", "Demo",
            "-configuration", "Release",
            "-archivePath", "/tmp/Demo/build/Demo.xcarchive",
            "-destination", "generic/platform=iOS",
            "-allowProvisioningUpdates"
        ])
    }
}
