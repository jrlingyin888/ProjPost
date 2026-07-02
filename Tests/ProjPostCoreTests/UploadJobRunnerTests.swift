import XCTest
@testable import ProjPostCore

final class UploadJobRunnerTests: XCTestCase {
    func testVaultDrivenRunnerWritesTemporaryKeyAndRemovesIt() async throws {
        let fileSystem = MemoryFileSystem()
        let vault = RecordingCredentialVault(privateKey: "-----BEGIN PRIVATE KEY-----\nABC123\n-----END PRIVATE KEY-----")
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "export ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "upload ok", stderr: "")
        ], fileSystem: fileSystem, exportArtifacts: ["Demo Release 2026.ipa"])
        let jobRunner = UploadJobRunner(
            commandRunner: runner,
            commandBuilder: UploadCommandBuilder(),
            fileSystem: fileSystem,
            credentialVault: vault
        )
        let accountID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
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
            id: accountID,
            displayName: "Company",
            keyID: "ABC123DEF4",
            issuerID: "issuer",
            teamID: "ACCOUNTTEAM1",
            lastVerifiedAt: nil
        )

        let events = try await jobRunner.runLocalUpload(project: project, account: account)

        XCTAssertEqual(events.map(\.step), [.archive, .exportIPA, .upload])
        XCTAssertEqual(events.last?.message, "upload ok")
        XCTAssertEqual(runner.commands.count, 3)
        XCTAssertEqual(vault.requests, [accountID])
        XCTAssertNotNil(fileSystem.written[URL(fileURLWithPath: "/tmp/Demo/build/ExportOptions.plist")])

        let exportCommand = runner.commands[1]
        let keyPathIndex = try XCTUnwrap(exportCommand.arguments.firstIndex(of: "-authenticationKeyPath"))
        let keyPath = try XCTUnwrap(exportCommand.arguments[safe: keyPathIndex + 1])
        XCTAssertEqual(keyPath, FileManager.default.temporaryDirectory.appendingPathComponent("AuthKey_ABC123DEF4.p8").path)
        XCTAssertEqual(runner.capturedAuthenticationKeyContents, "-----BEGIN PRIVATE KEY-----\nABC123\n-----END PRIVATE KEY-----")
        XCTAssertFalse(fileSystem.fileExists(URL(fileURLWithPath: keyPath)))

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
    }

    func testTemporaryKeyIsRemovedWhenExportFails() async throws {
        let fileSystem = MemoryFileSystem()
        let vault = RecordingCredentialVault(privateKey: "PRIVATE KEY")
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 1, stdout: "export details", stderr: "export failed")
        ], fileSystem: fileSystem, exportArtifacts: [])
        let jobRunner = UploadJobRunner(
            commandRunner: runner,
            commandBuilder: UploadCommandBuilder(),
            fileSystem: fileSystem,
            credentialVault: vault
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
        let account = AppleAccountProfile(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            displayName: "Company",
            keyID: "ABC123DEF4",
            issuerID: "issuer",
            teamID: "ACCOUNTTEAM1",
            lastVerifiedAt: nil
        )

        do {
            _ = try await jobRunner.runLocalUpload(project: project, account: account)
            XCTFail("Expected export to fail")
        } catch let error as UploadJobRunnerError {
            XCTAssertEqual(error, .commandFailed(step: .exportIPA, message: "export failed\n\nstdout:\nexport details"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(vault.requests, [account.id])
        XCTAssertFalse(fileSystem.fileExists(FileManager.default.temporaryDirectory.appendingPathComponent("AuthKey_ABC123DEF4.p8")))
    }

    func testRunnerThrowsWhenExportProducesNoIPA() async throws {
        let fileSystem = MemoryFileSystem()
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "export ok", stderr: "")
        ], fileSystem: fileSystem, exportArtifacts: [])
        let jobRunner = UploadJobRunner(
            commandRunner: runner,
            commandBuilder: UploadCommandBuilder(),
            fileSystem: fileSystem
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
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        do {
            _ = try await jobRunner.runLocalUpload(project: project, account: account, keyPath: "/tmp/AuthKey_ABC123DEF4.p8")
            XCTFail("Expected missing IPA error")
        } catch let error as UploadJobRunnerError {
            XCTAssertEqual(error, .missingExportedIPA(exportPath: "/tmp/Demo/build/export"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRunnerThrowsWhenExportProducesMultipleIPAs() async throws {
        let fileSystem = MemoryFileSystem()
        let runner = SequencedCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "archive ok", stderr: ""),
            CommandResult(exitCode: 0, stdout: "export ok", stderr: "")
        ], fileSystem: fileSystem, exportArtifacts: ["Demo A.ipa", "Demo B.ipa"])
        let jobRunner = UploadJobRunner(
            commandRunner: runner,
            commandBuilder: UploadCommandBuilder(),
            fileSystem: fileSystem
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
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        do {
            _ = try await jobRunner.runLocalUpload(project: project, account: account, keyPath: "/tmp/AuthKey_ABC123DEF4.p8")
            XCTFail("Expected ambiguous IPA error")
        } catch let error as UploadJobRunnerError {
            XCTAssertEqual(error, .ambiguousExportedIPAs(exportPath: "/tmp/Demo/build/export", candidates: ["Demo A.ipa", "Demo B.ipa"]))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class SequencedCommandRunner: CommandRunning {
    private var results: [CommandResult]
    private let fileSystem: MemoryFileSystem
    private let exportArtifacts: [String]
    private var didSeedExportArtifact = false
    var commands: [Command] = []
    private(set) var capturedAuthenticationKeyContents: String?

    init(results: [CommandResult], fileSystem: MemoryFileSystem, exportArtifacts: [String]) {
        self.results = results
        self.fileSystem = fileSystem
        self.exportArtifacts = exportArtifacts
    }

    func run(_ command: Command) async throws -> CommandResult {
        commands.append(command)
        if capturedAuthenticationKeyContents == nil,
           let keyPathIndex = command.arguments.firstIndex(of: "-authenticationKeyPath"),
           command.arguments.indices.contains(keyPathIndex + 1) {
            let keyPath = URL(fileURLWithPath: command.arguments[keyPathIndex + 1])
            capturedAuthenticationKeyContents = fileSystem.contents[keyPath.path]
        }
        if !didSeedExportArtifact, let exportPath = exportPath(for: command) {
            for artifact in exportArtifacts {
                fileSystem.addFile(named: artifact, in: exportPath)
            }
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
    var contents: [String: String] = [:]

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
        return written[url] ?? Data()
    }

    func writeData(_ data: Data, to url: URL) throws {
        written[url] = data
        contents[url.path] = String(data: data, encoding: .utf8)
        let parentPath = url.deletingLastPathComponent().path
        var entries = directories[parentPath, default: []]
        let fileName = url.lastPathComponent
        if !entries.contains(fileName) {
            entries.append(fileName)
            directories[parentPath] = entries
        }
    }

    func removeItem(_ url: URL) throws {
        written[url] = nil
        contents[url.path] = nil
        let parentPath = url.deletingLastPathComponent().path
        directories[parentPath]?.removeAll { $0 == url.lastPathComponent }
        if directories[parentPath]?.isEmpty == true {
            directories[parentPath] = nil
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private final class RecordingCredentialVault: CredentialVault {
    let privateKey: String
    private(set) var requests: [UUID] = []

    init(privateKey: String) {
        self.privateKey = privateKey
    }

    func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws {}

    func privateKey(for accountID: UUID) throws -> String {
        requests.append(accountID)
        return privateKey
    }

    func deletePrivateKey(for accountID: UUID) throws {}
}
