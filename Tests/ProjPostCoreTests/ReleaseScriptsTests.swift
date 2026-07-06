import XCTest

final class ReleaseScriptsTests: XCTestCase {
    func testSelectSigningIdentityPrefersDeveloperIDForConfiguredTeam() throws {
        let securityOutput = """
          1) AAAAA "Apple Development: Yating Wang (3K8TL5F9X2)"
          2) BBBBB "Developer ID Application: Someone Else (ABCDE12345)"
          3) CCCCC "Developer ID Application: Yating Wang (T46A6Q874U)"
          4) DDDDD "Apple Distribution: Yating Wang (T46A6Q874U)"
             4 valid identities found
        """

        let result = try runBashScript(
            "scripts/select_signing_identity.sh",
            environment: [
                "APPLE_TEAM_ID": "T46A6Q874U",
                "SECURITY_FIND_IDENTITY_OUTPUT": securityOutput
            ]
        )

        XCTAssertEqual(result.exitCode, 0, result.stderr)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "Developer ID Application: Yating Wang (T46A6Q874U)")
    }

    func testReleaseZipCreatesVersionedDeveloperIDArchive() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        let distDirectory = temporaryDirectory.appendingPathComponent("dist", isDirectory: true)
        let appDirectory = distDirectory.appendingPathComponent("JJPost.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        try "placeholder".write(
            to: appDirectory.appendingPathComponent("Contents.txt"),
            atomically: true,
            encoding: .utf8
        )

        let result = try runBashScript(
            "scripts/release_zip.sh",
            environment: [
                "APP_VERSION": "1.0.0",
                "APP_NAME": "JJPost",
                "DIST_DIR": distDirectory.path,
                "APP_DIR": appDirectory.path,
                "BUILD_IF_MISSING": "0",
                "RELEASE_KIND": "dev-id"
            ]
        )

        let expectedZip = distDirectory.appendingPathComponent("JJPost-1.0.0-dev-id.zip")
        XCTAssertEqual(result.exitCode, 0, result.stderr)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedZip.path))
        XCTAssertTrue(result.stdout.contains(expectedZip.path))
    }

    func testNotarizeAppDryRunPrintsSubmitAndStapleCommands() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        let appDirectory = temporaryDirectory.appendingPathComponent("JJPost.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        let result = try runBashScript(
            "scripts/notarize_app.sh",
            environment: [
                "APP_VERSION": "1.0.0",
                "APP_NAME": "JJPost",
                "APP_DIR": appDirectory.path,
                "DIST_DIR": temporaryDirectory.path,
                "NOTARYTOOL_PROFILE": "JJPostNotary",
                "DRY_RUN": "1"
            ]
        )

        XCTAssertEqual(result.exitCode, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("xcrun notarytool submit"))
        XCTAssertTrue(result.stdout.contains("--keychain-profile JJPostNotary"))
        XCTAssertTrue(result.stdout.contains("xcrun stapler staple"))
        XCTAssertTrue(result.stdout.contains(appDirectory.path))
    }

    private func runBashScript(_ relativePath: String, environment: [String: String]) throws -> ProcessResult {
        let scriptPath = repositoryRoot.appendingPathComponent(relativePath).path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]

        var mergedEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            mergedEnvironment[key] = value
        }
        process.environment = mergedEnvironment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private struct ProcessResult {
        var exitCode: Int32
        var stdout: String
        var stderr: String
    }
}
