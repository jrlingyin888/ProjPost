import XCTest
@testable import ProjPostCore

final class UploadJobRunnerTests: XCTestCase {
    func testRunnerEmitsArchiveExportUploadSteps() async throws {
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "export ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "upload ok", stderr: "")
        ])
        let jobRunner = UploadJobRunner(commandRunner: runner, commandBuilder: UploadCommandBuilder())
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
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let events = try await jobRunner.runLocalUpload(project: project, account: account, keyPath: "/tmp/AuthKey_ABC123DEF4.p8")

        XCTAssertEqual(events.map(\.step), [.archive, .exportIPA, .upload])
        XCTAssertEqual(events.last?.message, "upload ok")
    }
}

private final class SequencedCommandRunner: CommandRunning {
    private var results: [CommandResult]

    init(results: [CommandResult]) {
        self.results = results
    }

    func run(_ command: Command) async throws -> CommandResult {
        results.removeFirst()
    }
}
