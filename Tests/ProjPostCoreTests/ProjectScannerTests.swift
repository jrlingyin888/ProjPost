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

    func testScannerUsesDisplayNameForProjectProfileName() async throws {
        let runner = FakeCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: #"{"workspace":{"name":"Demo.xcworkspace","schemes":["Demo"]}}"#, stderr: ""),
            CommandResult(exitCode: 0, stdout: #"[{"target":"Demo","buildSettings":{"PRODUCT_BUNDLE_IDENTIFIER":"com.example.demo","MARKETING_VERSION":"1.2.3","CURRENT_PROJECT_VERSION":"45","DEVELOPMENT_TEAM":"ABCDE12345","INFOPLIST_KEY_CFBundleDisplayName":"Real App Name","PRODUCT_NAME":"Demo"}}]"#, stderr: "")
        ])
        let scanner = ProjectScanner(commandRunner: runner, fileSystem: ScannerFileSystem(entries: [
            "/tmp/folder_name/Demo.xcworkspace",
            "/tmp/folder_name/Demo.xcodeproj"
        ]))

        let result = try await scanner.scan(projectPath: URL(fileURLWithPath: "/tmp/folder_name"))

        XCTAssertEqual(result.displayName, "Real App Name")
        XCTAssertEqual(result.toProjectProfile().name, "Real App Name")
    }

    func testScannerPrefersMatchingTargetBuildSettings() async throws {
        let runner = FakeCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: #"{"workspace":{"name":"Demo.xcworkspace","schemes":["Demo"]}}"#, stderr: ""),
            CommandResult(exitCode: 0, stdout: #"[{"target":"DemoTests","buildSettings":{"PRODUCT_BUNDLE_IDENTIFIER":"com.example.demoTests","MARKETING_VERSION":"9.9.9","CURRENT_PROJECT_VERSION":"999","DEVELOPMENT_TEAM":"TESTTEAM"}},{"target":"Demo","buildSettings":{"PRODUCT_BUNDLE_IDENTIFIER":"com.example.demo","MARKETING_VERSION":"1.2.3","CURRENT_PROJECT_VERSION":"45","DEVELOPMENT_TEAM":"ABCDE12345"}}]"#, stderr: "")
        ])
        let scanner = ProjectScanner(commandRunner: runner, fileSystem: ScannerFileSystem(entries: [
            "/tmp/Demo/Demo.xcworkspace",
            "/tmp/Demo/Demo.xcodeproj"
        ]))

        let result = try await scanner.scan(projectPath: URL(fileURLWithPath: "/tmp/Demo"))

        XCTAssertEqual(result.bundleID, "com.example.demo")
        XCTAssertEqual(result.version, "1.2.3")
        XCTAssertEqual(result.buildNumber, "45")
        XCTAssertEqual(result.teamID, "ABCDE12345")
    }

    func testScannerPrefersAppSchemeOverDependencySchemes() async throws {
        let runner = FakeCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: #"{"workspace":{"name":"SCDL.xcworkspace","schemes":["Alamofire","Pods-SCDL","SCDL","SnapKit"]}}"#, stderr: ""),
            CommandResult(exitCode: 0, stdout: #"[{"target":"SCDL","buildSettings":{"PRODUCT_BUNDLE_IDENTIFIER":"com.scdl.xyz","MARKETING_VERSION":"1.2.5","CURRENT_PROJECT_VERSION":"1","DEVELOPMENT_TEAM":"KR42D74ZCX"}}]"#, stderr: "")
        ])
        let scanner = ProjectScanner(commandRunner: runner, fileSystem: ScannerFileSystem(entries: [
            "/tmp/scdl_ios_new/SCDL.xcworkspace",
            "/tmp/scdl_ios_new/SCDL.xcodeproj"
        ]))

        let result = try await scanner.scan(projectPath: URL(fileURLWithPath: "/tmp/scdl_ios_new"))

        XCTAssertEqual(result.selectedScheme, "SCDL")
        XCTAssertEqual(result.bundleID, "com.scdl.xyz")
        XCTAssertEqual(result.version, "1.2.5")
        XCTAssertEqual(result.buildNumber, "1")
        XCTAssertEqual(result.teamID, "KR42D74ZCX")
        XCTAssertEqual(runner.commands.last?.arguments.prefix(4), ["-showBuildSettings", "-json", "-scheme", "SCDL"])
    }

    func testScannerThrowsWhenProjectSelectorIsMissing() async {
        let runner = FakeCommandRunner(results: [])
        let scanner = ProjectScanner(commandRunner: runner, fileSystem: ScannerFileSystem(entries: []))
        let projectPath = URL(fileURLWithPath: "/tmp/Demo")

        do {
            _ = try await scanner.scan(projectPath: projectPath)
            XCTFail("Expected missingXcodeProject error")
        } catch let ProjectScannerError.missingXcodeProject(url) {
            XCTAssertEqual(url, projectPath)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(runner.commands.isEmpty)
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
    func removeItem(_ url: URL) throws {}
    func setPOSIXPermissions(_ permissions: Int, for url: URL) throws {}
}
