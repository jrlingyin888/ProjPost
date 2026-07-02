import XCTest
@testable import ProjPostCore

final class UploadJobRunnerTests: XCTestCase {
    func testRunnerUsesDiscoveredIPAAndAccountTeamID() async throws {
        let fileSystem = MemoryFileSystem()
        let writer = ExportOptionsPlistWriter(fileSystem: fileSystem)
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "export ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "upload ok", stderr: "")
        ], fileSystem: fileSystem)
        let jobRunner = UploadJobRunner(
            commandRunner: runner,
            commandBuilder: UploadCommandBuilder(),
            fileSystem: fileSystem,
            exportOptionsWriter: writer
        )
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
        let account = AppleAccountProfile(
            displayName: "Company",
            keyID: "ABC123DEF4",
            issuerID: "issuer",
            teamID: "ACCOUNTTEAM1",
            lastVerifiedAt: nil
        )

        let events = try await jobRunner.runLocalUpload(project: project, account: account, keyPath: "/tmp/AuthKey_ABC123DEF4.p8")

        XCTAssertEqual(events.map(\.step), [.archive, .exportIPA, .upload])
        XCTAssertEqual(events.last?.message, "upload ok")
        XCTAssertEqual(runner.commands.count, 3)
        XCTAssertEqual(
            runner.commands[2].arguments,
            [
                "altool",
                "--upload-app",
                "-f", "/tmp/Demo/build/export/Demo Release 2026.ipa",
                "-t", "ios",
                "--apiKey", "ABC123DEF4",
                "--apiIssuer", "issuer"
            ]
        )

        let plistURL = URL(fileURLWithPath: "/tmp/Demo/build/ExportOptions.plist")
        let plistData = try XCTUnwrap(fileSystem.written[plistURL])
        let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(plist?["teamID"] as? String, "ACCOUNTTEAM1")
    }

    func testRunnerPrefersStderrInFailureMessage() async throws {
        let fileSystem = MemoryFileSystem()
        let writer = ExportOptionsPlistWriter(fileSystem: fileSystem)
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 1, stdout: "export details", stderr: "export failed")
        ], fileSystem: fileSystem)
        let jobRunner = UploadJobRunner(
            commandRunner: runner,
            commandBuilder: UploadCommandBuilder(),
            fileSystem: fileSystem,
            exportOptionsWriter: writer
        )
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
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: "ACCOUNTTEAM1", lastVerifiedAt: nil)

        do {
            _ = try await jobRunner.runLocalUpload(project: project, account: account, keyPath: "/tmp/AuthKey_ABC123DEF4.p8")
            XCTFail("Expected upload runner to throw")
        } catch let error as UploadJobRunnerError {
            XCTAssertEqual(error, .commandFailed(step: .exportIPA, message: "export failed\n\nstdout:\nexport details"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class SequencedCommandRunner: CommandRunning {
    private var results: [CommandResult]
    private let fileSystem: MemoryFileSystem
    private var didSeedExportArtifact = false
    var commands: [Command] = []

    init(results: [CommandResult], fileSystem: MemoryFileSystem) {
        self.results = results
        self.fileSystem = fileSystem
    }

    func run(_ command: Command) async throws -> CommandResult {
        commands.append(command)
        if !didSeedExportArtifact, let exportPath = exportPath(for: command) {
            fileSystem.addFile(named: "Demo Release 2026.ipa", in: exportPath)
            didSeedExportArtifact = true
        }
        return results.removeFirst()
    }

    private func exportPath(for command: Command) -> URL? {
        guard let index = command.arguments.firstIndex(of: "-exportPath"), command.arguments.indices.contains(index + 1) else {
            return nil
        }
        return URL(fileURLWithPath: command.arguments[index + 1])
    }
}

private final class MemoryFileSystem: FileSysteming {
    var written: [URL: Data] = [:]
    var directories: [String: [String]] = [:]

    func fileExists(_ url: URL) -> Bool {
        written[url] != nil || directories[url.path] != nil
    }

    func contentsOfDirectory(_ url: URL) throws -> [String] {
        directories[url.path] ?? []
    }

    func createDirectory(_ url: URL) throws {
        directories[url.path] = directories[url.path] ?? []
    }

    func readData(_ url: URL) throws -> Data {
        written[url] ?? Data()
    }

    func writeData(_ data: Data, to url: URL) throws {
        written[url] = data
        let parentPath = url.deletingLastPathComponent().path
        var entries = directories[parentPath, default: []]
        let fileName = url.lastPathComponent
        if !entries.contains(fileName) {
            entries.append(fileName)
            directories[parentPath] = entries
        }
    }

    func addFile(named name: String, in directory: URL) {
        var entries = directories[directory.path, default: []]
        if !entries.contains(name) {
            entries.append(name)
            directories[directory.path] = entries
        }
    }
}
