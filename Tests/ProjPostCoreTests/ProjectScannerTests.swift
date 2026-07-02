import XCTest
@testable import ProjPostCore

final class ProjectScannerTests: XCTestCase {
    func testScannerReadsWorkspaceSchemeAndBuildSettings() async throws {
        let runner = FakeCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: #"{"workspace":{"name":"Demo.xcworkspace","schemes":["Demo"]}}"#, stderr: ""),
            CommandResult(exitCode: 0, stdout: #"[{"target":"Demo","buildSettings":{"PRODUCT_BUNDLE_IDENTIFIER":"com.example.demo","MARKETING_VERSION":"1.2.3","CURRENT_PROJECT_VERSION":"45","DEVELOPMENT_TEAM":"ABCDE12345"}}]"#, stderr: "")
        ])
        let scanner = ProjectScanner(commandRunner: runner, fileSystem: ScannerFileSystem(entries: [
            "/tmp/Demo/Demo.xcworkspace",
            "/tmp/Demo/Demo.xcodeproj"
        ]))

        let result = try await scanner.scan(projectPath: URL(fileURLWithPath: "/tmp/Demo"))

        XCTAssertEqual(result.workspacePath?.path, "/tmp/Demo/Demo.xcworkspace")
        XCTAssertEqual(result.projectFilePath?.path, "/tmp/Demo/Demo.xcodeproj")
        XCTAssertEqual(result.schemes, ["Demo"])
        XCTAssertEqual(result.bundleID, "com.example.demo")
        XCTAssertEqual(result.version, "1.2.3")
        XCTAssertEqual(result.buildNumber, "45")
        XCTAssertEqual(result.teamID, "ABCDE12345")
    }
}

private final class FakeCommandRunner: CommandRunning {
    private var results: [CommandResult]
    private(set) var commands: [Command] = []

    init(results: [CommandResult]) {
        self.results = results
    }

    func run(_ command: Command) async throws -> CommandResult {
        commands.append(command)
        return results.removeFirst()
    }
}

private final class ScannerFileSystem: FileSysteming {
    private let entries: Set<String>

    init(entries: [String]) {
        self.entries = Set(entries)
    }

    func fileExists(_ url: URL) -> Bool {
        entries.contains(url.path)
    }

    func contentsOfDirectory(_ url: URL) throws -> [String] {
        entries
            .filter { $0.hasPrefix(url.path + "/") }
            .map { URL(fileURLWithPath: $0).lastPathComponent }
            .sorted()
    }

    func createDirectory(_ url: URL) throws {}
    func readData(_ url: URL) throws -> Data { Data() }
    func writeData(_ data: Data, to url: URL) throws {}
}
