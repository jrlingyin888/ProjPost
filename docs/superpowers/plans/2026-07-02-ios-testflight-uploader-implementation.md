# iOS TestFlight Uploader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first local macOS MVP for managing iOS project profiles, checking App Store Connect compatibility, uploading builds, and distributing processed builds to TestFlight groups.

**Architecture:** Use a Swift Package with a SwiftUI executable target (`ProjPostApp`) and a testable core library target (`ProjPostCore`). Keep UI thin: ViewModels call service protocols from the core library, while command execution, Keychain, App Store Connect API calls, project scanning, project mutation, and upload orchestration live in focused core files.

**Tech Stack:** Swift 5.9+, SwiftUI, Combine, Foundation, Security, Swift Crypto, XcodeProj, XCTest, `xcodebuild`, and Xcode-provided App Store upload tooling.

## Global Constraints

- V1 is local-first: no Apple credential material is uploaded to any third-party server.
- Sensitive `.p8` private key material is stored in macOS Keychain.
- JWTs are generated on demand and not persisted.
- The Mac is the only build machine and credential holder.
- Product users should not need terminal commands to complete upload and TestFlight distribution.
- Project file edits must be backed up before writing.
- Git dirty-state detection is advanced context only and must not block product users.
- Red configuration issues block upload; yellow issues require explicit confirmation.
- App Store formal review submission automation is out of V1.
- Direct iPhone/iPad build execution is out of V1.
- Xcode version must be shown in environment checks because Apple upload requirements changed after 2026-04-28.

---

## Planned File Structure

`Package.swift`
- Declares app, core, and test targets plus dependencies.

`Sources/ProjPostApp/ProjPostApp.swift`
- SwiftUI app entrypoint.

`Sources/ProjPostApp/Views/ContentView.swift`
- Two-pane app shell.

`Sources/ProjPostApp/Views/ProjectListView.swift`
- Left-side project cards and add-project action.

`Sources/ProjPostApp/Views/ProjectDetailView.swift`
- Right-side project workbench.

`Sources/ProjPostApp/Views/CheckResultsView.swift`
- Red/yellow/green configuration check display.

`Sources/ProjPostApp/Views/UploadProgressView.swift`
- Step timeline and detailed log console.

`Sources/ProjPostCore/Models/DomainModels.swift`
- Shared value types for projects, accounts, checks, builds, beta groups, and upload jobs.

`Sources/ProjPostCore/AppState/AppViewModel.swift`
- UI state container and action coordinator that stays testable outside the executable app target.

`Sources/ProjPostCore/Support/CommandRunner.swift`
- Testable wrapper around `Process`.

`Sources/ProjPostCore/Support/FileSystem.swift`
- Testable filesystem wrapper.

`Sources/ProjPostCore/Storage/ProjectProfileStore.swift`
- JSON storage for project profiles and upload history.

`Sources/ProjPostCore/Credentials/CredentialVault.swift`
- Protocol and Keychain-backed implementation for credential storage.

`Sources/ProjPostCore/AppStoreConnect/AppStoreConnectJWTSigner.swift`
- ES256 JWT signing for App Store Connect API.

`Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`
- HTTP client for App Store Connect endpoints used by V1.

`Sources/ProjPostCore/Project/ProjectScanner.swift`
- Reads workspace/project, schemes, build settings, Bundle ID, Version, Build Number, and Team ID.

`Sources/ProjPostCore/Project/ProjectMutator.swift`
- Creates mutation plan, backs up touched files, and applies supported project changes.

`Sources/ProjPostCore/Checks/ConfigurationCheckEngine.swift`
- Combines local environment checks and App Store Connect checks into UI-ready results.

`Sources/ProjPostCore/Upload/UploadCommandBuilder.swift`
- Builds `xcodebuild` and upload commands from a project profile and account.

`Sources/ProjPostCore/Upload/UploadJobRunner.swift`
- Long-running upload state machine, log streaming, cancellation, build polling, and TestFlight assignment.

`Tests/ProjPostCoreTests/*.swift`
- Unit tests and integration-style tests with fakes and fixtures.

`docs/manual-test-checklist.md`
- Real-account manual validation checklist.

---

### Task 1: Swift Package Scaffold and Core Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/ProjPostCore/Models/DomainModels.swift`
- Create: `Sources/ProjPostCore/Support/CommandRunner.swift`
- Create: `Sources/ProjPostApp/ProjPostApp.swift`
- Create: `Sources/ProjPostApp/Views/ContentView.swift`
- Create: `Tests/ProjPostCoreTests/DomainModelsTests.swift`

**Interfaces:**
- Produces: `ProjectProfile`, `AppleAccountProfile`, `CheckResult`, `UploadStep`, `UploadJobState`
- Produces: `CommandRunning.run(_:) async throws -> CommandResult`
- Later tasks consume these models and the command runner protocol.

- [ ] **Step 1: Write the failing domain model test**

Create `Tests/ProjPostCoreTests/DomainModelsTests.swift`:

```swift
import XCTest
@testable import ProjPostCore

final class DomainModelsTests: XCTestCase {
    func testProjectProfileDisplaysVersionAndBuild() {
        let profile = ProjectProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Demo",
            projectPath: "/tmp/Demo",
            workspacePath: "/tmp/Demo/Demo.xcworkspace",
            projectFilePath: "/tmp/Demo/Demo.xcodeproj",
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.example.demo",
            version: "1.0.0",
            buildNumber: "12",
            teamID: "ABCDE12345",
            selectedAccountID: nil,
            lastUpload: nil
        )

        XCTAssertEqual(profile.versionDisplay, "v1.0.0 (12)")
        XCTAssertEqual(profile.statusLabel, "未配置")
    }

    func testCheckSeverityBlocksUploadOnlyForRedResults() {
        let red = CheckResult(id: "bundle", title: "Bundle ID 不存在", message: "请修改 Bundle ID", severity: .red)
        let yellow = CheckResult(id: "team", title: "Team ID 无法确认", message: "可以继续但建议确认", severity: .yellow)

        XCTAssertTrue([red, yellow].blocksUpload)
        XCTAssertFalse([yellow].blocksUpload)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails before scaffold exists**

Run:

```bash
swift test --filter DomainModelsTests
```

Expected: FAIL because `Package.swift` and `ProjPostCore` do not exist.

- [ ] **Step 3: Create the Swift package and minimal app shell**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjPost",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ProjPostCore", targets: ["ProjPostCore"]),
        .executable(name: "ProjPostApp", targets: ["ProjPostApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.0")
    ],
    targets: [
        .target(
            name: "ProjPostCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "XcodeProj", package: "XcodeProj")
            ]
        ),
        .executableTarget(
            name: "ProjPostApp",
            dependencies: ["ProjPostCore"]
        ),
        .testTarget(
            name: "ProjPostCoreTests",
            dependencies: ["ProjPostCore"]
        )
    ]
)
```

Create `Sources/ProjPostCore/Models/DomainModels.swift`:

```swift
import Foundation

public struct ProjectProfile: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var projectPath: String
    public var workspacePath: String?
    public var projectFilePath: String?
    public var scheme: String?
    public var configuration: String
    public var bundleID: String?
    public var version: String?
    public var buildNumber: String?
    public var teamID: String?
    public var selectedAccountID: UUID?
    public var lastUpload: UploadSummary?

    public init(
        id: UUID = UUID(),
        name: String,
        projectPath: String,
        workspacePath: String?,
        projectFilePath: String?,
        scheme: String?,
        configuration: String = "Release",
        bundleID: String?,
        version: String?,
        buildNumber: String?,
        teamID: String?,
        selectedAccountID: UUID?,
        lastUpload: UploadSummary?
    ) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.workspacePath = workspacePath
        self.projectFilePath = projectFilePath
        self.scheme = scheme
        self.configuration = configuration
        self.bundleID = bundleID
        self.version = version
        self.buildNumber = buildNumber
        self.teamID = teamID
        self.selectedAccountID = selectedAccountID
        self.lastUpload = lastUpload
    }

    public var versionDisplay: String {
        let versionText = version ?? "-"
        let buildText = buildNumber ?? "-"
        return "v\(versionText) (\(buildText))"
    }

    public var statusLabel: String {
        guard let lastUpload else { return "未配置" }
        return lastUpload.succeeded ? "最近上传成功" : "最近上传失败"
    }
}

public struct UploadSummary: Codable, Equatable {
    public var version: String
    public var buildNumber: String
    public var uploadedAt: Date
    public var succeeded: Bool
    public var message: String

    public init(version: String, buildNumber: String, uploadedAt: Date, succeeded: Bool, message: String) {
        self.version = version
        self.buildNumber = buildNumber
        self.uploadedAt = uploadedAt
        self.succeeded = succeeded
        self.message = message
    }
}

public struct AppleAccountProfile: Codable, Equatable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var keyID: String
    public var issuerID: String
    public var teamID: String?
    public var lastVerifiedAt: Date?

    public init(id: UUID = UUID(), displayName: String, keyID: String, issuerID: String, teamID: String?, lastVerifiedAt: Date?) {
        self.id = id
        self.displayName = displayName
        self.keyID = keyID
        self.issuerID = issuerID
        self.teamID = teamID
        self.lastVerifiedAt = lastVerifiedAt
    }
}

public enum CheckSeverity: String, Codable, Equatable {
    case green
    case yellow
    case red
}

public struct CheckResult: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var message: String
    public var severity: CheckSeverity

    public init(id: String, title: String, message: String, severity: CheckSeverity) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
    }
}

public extension Array where Element == CheckResult {
    var blocksUpload: Bool {
        contains { $0.severity == .red }
    }
}

public enum UploadStep: String, Codable, CaseIterable, Equatable {
    case readProject
    case validateAccount
    case checkBundleAndApp
    case backupProjectFiles
    case applyProjectChanges
    case archive
    case exportIPA
    case validateIPA
    case upload
    case waitForAppleProcessing
    case assignTestFlightGroups
    case fetchPublicLink
}

public enum UploadJobState: Equatable {
    case idle
    case running(step: UploadStep)
    case succeeded(message: String)
    case failed(message: String)
    case cancelled
}
```

Create `Sources/ProjPostCore/Support/CommandRunner.swift`:

```swift
import Foundation

public struct Command: Equatable {
    public var executableURL: URL
    public var arguments: [String]
    public var workingDirectory: URL?
    public var environment: [String: String]

    public init(executableURL: URL, arguments: [String], workingDirectory: URL? = nil, environment: [String: String] = [:]) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

public struct CommandResult: Equatable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol CommandRunning {
    func run(_ command: Command) async throws -> CommandResult
}

public final class ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ command: Command) async throws -> CommandResult {
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectory
        process.environment = command.environment.isEmpty ? nil : command.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
```

Create `Sources/ProjPostApp/ProjPostApp.swift`:

```swift
import SwiftUI

@main
struct ProjPostApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1120, minHeight: 720)
        }
    }
}
```

Create `Sources/ProjPostApp/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("项目列表")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            Text("选择或添加项目")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter DomainModelsTests
```

Expected: PASS with 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold Swift package and core models"
```

---

### Task 2: Project Profile Storage

**Files:**
- Create: `Sources/ProjPostCore/Support/FileSystem.swift`
- Create: `Sources/ProjPostCore/Storage/ProjectProfileStore.swift`
- Create: `Tests/ProjPostCoreTests/ProjectProfileStoreTests.swift`

**Interfaces:**
- Consumes: `ProjectProfile`
- Produces: `FileSysteming`
- Produces: `ProjectProfileStore.load() throws -> [ProjectProfile]`
- Produces: `ProjectProfileStore.save(_:) throws`
- Later UI and services use the store to persist project cards.

- [ ] **Step 1: Write the failing storage test**

Create `Tests/ProjPostCoreTests/ProjectProfileStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter ProjectProfileStoreTests
```

Expected: FAIL because `ProjectProfileStore` and `LocalFileSystem` do not exist.

- [ ] **Step 3: Implement filesystem and JSON store**

Create `Sources/ProjPostCore/Support/FileSystem.swift`:

```swift
import Foundation

public protocol FileSysteming {
    func fileExists(_ url: URL) -> Bool
    func contentsOfDirectory(_ url: URL) throws -> [String]
    func createDirectory(_ url: URL) throws
    func readData(_ url: URL) throws -> Data
    func writeData(_ data: Data, to url: URL) throws
}

public final class LocalFileSystem: FileSysteming {
    public init() {}

    public func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func contentsOfDirectory(_ url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path)
    }

    public func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func readData(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try createDirectory(parent)
        try data.write(to: url, options: [.atomic])
    }
}
```

Create `Sources/ProjPostCore/Storage/ProjectProfileStore.swift`:

```swift
import Foundation

public final class ProjectProfileStore {
    private let fileURL: URL
    private let fileSystem: FileSysteming
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, fileSystem: FileSysteming = LocalFileSystem()) {
        self.fileURL = fileURL
        self.fileSystem = fileSystem
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public static func defaultStore(fileSystem: FileSysteming = LocalFileSystem()) -> ProjectProfileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("ProjPost", isDirectory: true).appendingPathComponent("projects.json")
        return ProjectProfileStore(fileURL: url, fileSystem: fileSystem)
    }

    public func load() throws -> [ProjectProfile] {
        guard fileSystem.fileExists(fileURL) else { return [] }
        let data = try fileSystem.readData(fileURL)
        return try decoder.decode([ProjectProfile].self, from: data)
    }

    public func save(_ profiles: [ProjectProfile]) throws {
        let data = try encoder.encode(profiles)
        try fileSystem.writeData(data, to: fileURL)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter ProjectProfileStoreTests
```

Expected: PASS with 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/Support/FileSystem.swift Sources/ProjPostCore/Storage/ProjectProfileStore.swift Tests/ProjPostCoreTests/ProjectProfileStoreTests.swift
git commit -m "feat: persist project profiles"
```

---

### Task 3: Project Scanner

**Files:**
- Create: `Sources/ProjPostCore/Project/ProjectScanner.swift`
- Create: `Tests/ProjPostCoreTests/ProjectScannerTests.swift`

**Interfaces:**
- Consumes: `CommandRunning`
- Produces: `ProjectScanner.scan(projectPath:) async throws -> ProjectScanResult`
- Produces: `ProjectScanResult.toProjectProfile(nameOverride:) -> ProjectProfile`
- Later check engine and UI use scanner results to prefill project details.

- [ ] **Step 1: Write failing scanner tests**

Create `Tests/ProjPostCoreTests/ProjectScannerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter ProjectScannerTests
```

Expected: FAIL because `ProjectScanner` does not exist.

- [ ] **Step 3: Implement scanner**

Create `Sources/ProjPostCore/Project/ProjectScanner.swift`:

```swift
import Foundation

public struct ProjectScanResult: Equatable {
    public var projectPath: URL
    public var workspacePath: URL?
    public var projectFilePath: URL?
    public var schemes: [String]
    public var selectedScheme: String?
    public var bundleID: String?
    public var version: String?
    public var buildNumber: String?
    public var teamID: String?

    public func toProjectProfile(nameOverride: String? = nil) -> ProjectProfile {
        ProjectProfile(
            name: nameOverride ?? projectPath.lastPathComponent,
            projectPath: projectPath.path,
            workspacePath: workspacePath?.path,
            projectFilePath: projectFilePath?.path,
            scheme: selectedScheme,
            configuration: "Release",
            bundleID: bundleID,
            version: version,
            buildNumber: buildNumber,
            teamID: teamID,
            selectedAccountID: nil,
            lastUpload: nil
        )
    }
}

public final class ProjectScanner {
    private let commandRunner: CommandRunning
    private let fileSystem: FileSysteming

    public init(commandRunner: CommandRunning, fileSystem: FileSysteming = LocalFileSystem()) {
        self.commandRunner = commandRunner
        self.fileSystem = fileSystem
    }

    public func scan(projectPath: URL) async throws -> ProjectScanResult {
        let workspace = findFirst(projectPath: projectPath, suffix: ".xcworkspace")
        let projectFile = findFirst(projectPath: projectPath, suffix: ".xcodeproj")
        let listJSON = try await runXcodebuildList(projectPath: projectPath, workspace: workspace, projectFile: projectFile)
        let schemes = try parseSchemes(from: listJSON)
        let selectedScheme = schemes.first
        let settings = try await runBuildSettings(projectPath: projectPath, workspace: workspace, projectFile: projectFile, scheme: selectedScheme)

        return ProjectScanResult(
            projectPath: projectPath,
            workspacePath: workspace,
            projectFilePath: projectFile,
            schemes: schemes,
            selectedScheme: selectedScheme,
            bundleID: settings["PRODUCT_BUNDLE_IDENTIFIER"],
            version: settings["MARKETING_VERSION"],
            buildNumber: settings["CURRENT_PROJECT_VERSION"],
            teamID: settings["DEVELOPMENT_TEAM"]
        )
    }

    private func findFirst(projectPath: URL, suffix: String) -> URL? {
        let candidates = (try? fileSystem.contentsOfDirectory(projectPath)) ?? []
        return candidates.sorted().first { $0.hasSuffix(suffix) }.map { projectPath.appendingPathComponent($0) }
    }

    private func runXcodebuildList(projectPath: URL, workspace: URL?, projectFile: URL?) async throws -> String {
        var args = ["-list", "-json"]
        if let workspace {
            args += ["-workspace", workspace.path]
        } else if let projectFile {
            args += ["-project", projectFile.path]
        }
        let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: args, workingDirectory: projectPath))
        guard result.exitCode == 0 else { throw ProjectScannerError.commandFailed(result.stderr) }
        return result.stdout
    }

    private func runBuildSettings(projectPath: URL, workspace: URL?, projectFile: URL?, scheme: String?) async throws -> [String: String] {
        guard let scheme else { return [:] }
        var args = ["-showBuildSettings", "-json", "-scheme", scheme]
        if let workspace {
            args += ["-workspace", workspace.path]
        } else if let projectFile {
            args += ["-project", projectFile.path]
        }
        let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: args, workingDirectory: projectPath))
        guard result.exitCode == 0 else { throw ProjectScannerError.commandFailed(result.stderr) }
        return try parseBuildSettings(from: result.stdout)
    }

    private func parseSchemes(from json: String) throws -> [String] {
        let data = Data(json.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let workspaceSchemes = ((object?["workspace"] as? [String: Any])?["schemes"] as? [String]) ?? []
        let projectSchemes = ((object?["project"] as? [String: Any])?["schemes"] as? [String]) ?? []
        return workspaceSchemes.isEmpty ? projectSchemes : workspaceSchemes
    }

    private func parseBuildSettings(from json: String) throws -> [String: String] {
        let data = Data(json.utf8)
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let settings = array?.first?["buildSettings"] as? [String: Any]
        return settings?.compactMapValues { $0 as? String } ?? [:]
    }
}

public enum ProjectScannerError: Error, Equatable {
    case commandFailed(String)
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter ProjectScannerTests
```

Expected: PASS with 1 test.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/Project/ProjectScanner.swift Tests/ProjPostCoreTests/ProjectScannerTests.swift
git commit -m "feat: scan Xcode project settings"
```

---

### Task 4: Credential Vault and JWT Signing

**Files:**
- Create: `Sources/ProjPostCore/Credentials/CredentialVault.swift`
- Create: `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectJWTSigner.swift`
- Create: `Tests/ProjPostCoreTests/AppStoreConnectJWTSignerTests.swift`

**Interfaces:**
- Consumes: `AppleAccountProfile`
- Produces: `CredentialVault.savePrivateKey(_:for:) throws`
- Produces: `CredentialVault.privateKey(for:) throws -> String`
- Produces: `AppStoreConnectJWTSigner.makeJWT(account:privateKeyPEM:issuedAt:) throws -> String`
- Later API client consumes signed JWTs.

- [ ] **Step 1: Write failing JWT signer test**

Create `Tests/ProjPostCoreTests/AppStoreConnectJWTSignerTests.swift`:

```swift
import XCTest
import Crypto
@testable import ProjPostCore

final class AppStoreConnectJWTSignerTests: XCTestCase {
    func testJWTContainsExpectedHeaderAndPayloadFields() throws {
        let privateKey = P256.Signing.PrivateKey()
        let pem = privateKey.pemRepresentation
        let account = AppleAccountProfile(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            displayName: "Company",
            keyID: "ABC123DEF4",
            issuerID: "69a6de7f-1111-2222-3333-444444444444",
            teamID: nil,
            lastVerifiedAt: nil
        )

        let jwt = try AppStoreConnectJWTSigner().makeJWT(
            account: account,
            privateKeyPEM: pem,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let parts = jwt.split(separator: ".").map(String.init)
        XCTAssertEqual(parts.count, 3)

        let header = try XCTUnwrap(Self.decodeJSONPart(parts[0]))
        let payload = try XCTUnwrap(Self.decodeJSONPart(parts[1]))

        XCTAssertEqual(header["alg"] as? String, "ES256")
        XCTAssertEqual(header["kid"] as? String, "ABC123DEF4")
        XCTAssertEqual(header["typ"] as? String, "JWT")
        XCTAssertEqual(payload["iss"] as? String, "69a6de7f-1111-2222-3333-444444444444")
        XCTAssertEqual(payload["aud"] as? String, "appstoreconnect-v1")
    }

    private static func decodeJSONPart(_ text: String) throws -> [String: Any]? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter AppStoreConnectJWTSignerTests
```

Expected: FAIL because credential and JWT files do not exist.

- [ ] **Step 3: Implement credential vault and signer**

Create `Sources/ProjPostCore/Credentials/CredentialVault.swift`:

```swift
import Foundation
import Security

public protocol CredentialVault {
    func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws
    func privateKey(for accountID: UUID) throws -> String
    func deletePrivateKey(for accountID: UUID) throws
}

public enum CredentialVaultError: Error, Equatable {
    case itemNotFound
    case invalidData
    case keychainStatus(OSStatus)
}

public final class KeychainCredentialVault: CredentialVault {
    private let service = "com.projpost.appstoreconnect"

    public init() {}

    public func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws {
        let account = accountID.uuidString
        let data = Data(privateKeyPEM.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialVaultError.keychainStatus(status) }
    }

    public func privateKey(for accountID: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { throw CredentialVaultError.itemNotFound }
        guard status == errSecSuccess else { throw CredentialVaultError.keychainStatus(status) }
        guard let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
            throw CredentialVaultError.invalidData
        }
        return text
    }

    public func deletePrivateKey(for accountID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialVaultError.keychainStatus(status) }
    }
}
```

Create `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectJWTSigner.swift`:

```swift
import Crypto
import Foundation

public struct AppStoreConnectJWTSigner {
    public init() {}

    public func makeJWT(account: AppleAccountProfile, privateKeyPEM: String, issuedAt: Date = Date()) throws -> String {
        let header: [String: Any] = [
            "alg": "ES256",
            "kid": account.keyID,
            "typ": "JWT"
        ]
        let issued = Int(issuedAt.timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": account.issuerID,
            "iat": issued,
            "exp": issued + 20 * 60,
            "aud": "appstoreconnect-v1"
        ]
        let headerPart = try Self.base64URLJSON(header)
        let payloadPart = try Self.base64URLJSON(payload)
        let signingInput = "\(headerPart).\(payloadPart)"
        let key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        let signature = try key.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(Self.base64URL(signature.rawRepresentation))"
    }

    private static func base64URLJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return base64URL(data)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter AppStoreConnectJWTSignerTests
```

Expected: PASS with 1 test.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/Credentials Sources/ProjPostCore/AppStoreConnect/AppStoreConnectJWTSigner.swift Tests/ProjPostCoreTests/AppStoreConnectJWTSignerTests.swift
git commit -m "feat: store credentials and sign app store connect jwt"
```

---

### Task 5: App Store Connect Client

**Files:**
- Create: `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`
- Create: `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`

**Interfaces:**
- Consumes: signed JWT string.
- Produces: `AppStoreConnectClientProtocol`
- Produces: `fetchApp(bundleID:) async throws -> ASCApp?`
- Produces: `fetchBundleID(identifier:) async throws -> ASCBundleID?`
- Produces: `fetchBuilds(appID:buildNumber:) async throws -> [ASCBuild]`
- Produces: `fetchBetaGroups(appID:) async throws -> [ASCBetaGroup]`
- Produces: `addBuild(_:toBetaGroup:) async throws`
- Produces: `enablePublicLink(betaGroupID:limit:) async throws -> ASCBetaGroup`

- [ ] **Step 1: Write failing API client test**

Create `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`:

```swift
import XCTest
@testable import ProjPostCore

final class AppStoreConnectClientTests: XCTestCase {
    func testFetchAppByBundleIDMapsResponse() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":[{"id":"123","type":"apps","attributes":{"name":"Demo","bundleId":"com.example.demo","sku":"DEMO"}}]}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let app = try await client.fetchApp(bundleID: "com.example.demo")

        XCTAssertEqual(app?.id, "123")
        XCTAssertEqual(app?.name, "Demo")
        XCTAssertEqual(app?.bundleID, "com.example.demo")
        XCTAssertEqual(transport.requests.first?.headers["Authorization"], "Bearer token")
        XCTAssertEqual(transport.requests.first?.path, "/v1/apps")
        XCTAssertEqual(transport.requests.first?.queryItems["filter[bundleId]"], "com.example.demo")
    }

    func testFetchBetaGroupsMapsPublicLink() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":[{"id":"group1","type":"betaGroups","attributes":{"name":"外部公开测试","isInternalGroup":false,"publicLinkEnabled":true,"publicLink":"https://testflight.apple.com/join/abc","publicLinkLimit":100}}]}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let groups = try await client.fetchBetaGroups(appID: "123")

        XCTAssertEqual(groups, [
            ASCBetaGroup(id: "group1", name: "外部公开测试", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/abc", publicLinkLimit: 100)
        ])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter AppStoreConnectClientTests
```

Expected: FAIL because `AppStoreConnectClient` does not exist.

- [ ] **Step 3: Implement API models, protocol, and HTTP client**

Create `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ASCApp: Equatable {
    public var id: String
    public var name: String
    public var bundleID: String
}

public struct ASCBundleID: Equatable {
    public var id: String
    public var identifier: String
    public var platform: String?
}

public struct ASCBuild: Equatable {
    public var id: String
    public var version: String
    public var processingState: String?
}

public struct ASCBetaGroup: Equatable {
    public var id: String
    public var name: String
    public var isInternalGroup: Bool
    public var publicLinkEnabled: Bool
    public var publicLink: String?
    public var publicLinkLimit: Int?
}

public protocol AppStoreConnectClientProtocol {
    func fetchApp(bundleID: String) async throws -> ASCApp?
    func fetchBundleID(identifier: String) async throws -> ASCBundleID?
    func fetchBuilds(appID: String, buildNumber: String?) async throws -> [ASCBuild]
    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup]
    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws
    func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup
}

public struct ASCRequest: Equatable {
    public var method: String
    public var path: String
    public var queryItems: [String: String]
    public var headers: [String: String]
    public var body: Data?
}

public struct ASCTransportResponse {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol ASCTransport {
    func send(_ request: ASCRequest) async throws -> ASCTransportResponse
}

public enum AppStoreConnectError: Error, Equatable {
    case badStatus(Int, String)
    case malformedResponse
}

public final class AppStoreConnectClient: AppStoreConnectClientProtocol {
    private let jwtProvider: () throws -> String
    private let transport: ASCTransport

    public init(jwtProvider: @escaping () throws -> String, transport: ASCTransport = URLSessionASCTransport()) {
        self.jwtProvider = jwtProvider
        self.transport = transport
    }

    public func fetchApp(bundleID: String) async throws -> ASCApp? {
        let json = try await get(path: "/v1/apps", query: ["filter[bundleId]": bundleID])
        return try dataArray(json).first.map { item in
            let attributes = item["attributes"] as? [String: Any]
            return ASCApp(
                id: item["id"] as? String ?? "",
                name: attributes?["name"] as? String ?? "",
                bundleID: attributes?["bundleId"] as? String ?? ""
            )
        }
    }

    public func fetchBundleID(identifier: String) async throws -> ASCBundleID? {
        let json = try await get(path: "/v1/bundleIds", query: ["filter[identifier]": identifier, "filter[platform]": "IOS"])
        return try dataArray(json).first.map { item in
            let attributes = item["attributes"] as? [String: Any]
            return ASCBundleID(
                id: item["id"] as? String ?? "",
                identifier: attributes?["identifier"] as? String ?? "",
                platform: attributes?["platform"] as? String
            )
        }
    }

    public func fetchBuilds(appID: String, buildNumber: String?) async throws -> [ASCBuild] {
        var query = ["filter[app]": appID]
        if let buildNumber { query["filter[version]"] = buildNumber }
        let json = try await get(path: "/v1/builds", query: query)
        return try dataArray(json).map { item in
            let attributes = item["attributes"] as? [String: Any]
            return ASCBuild(
                id: item["id"] as? String ?? "",
                version: attributes?["version"] as? String ?? "",
                processingState: attributes?["processingState"] as? String
            )
        }
    }

    public func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup] {
        let json = try await get(path: "/v1/betaGroups", query: ["filter[app]": appID])
        return try dataArray(json).map(Self.mapBetaGroup)
    }

    public func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {
        let body = [
            "data": [
                ["type": "builds", "id": buildID]
            ]
        ]
        _ = try await send(method: "POST", path: "/v1/betaGroups/\(betaGroupID)/relationships/builds", query: [:], jsonBody: body)
    }

    public func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup {
        var attributes: [String: Any] = ["publicLinkEnabled": true]
        if let limit {
            attributes["publicLinkLimitEnabled"] = true
            attributes["publicLinkLimit"] = limit
        }
        let body: [String: Any] = [
            "data": [
                "type": "betaGroups",
                "id": betaGroupID,
                "attributes": attributes
            ]
        ]
        let json = try await send(method: "PATCH", path: "/v1/betaGroups/\(betaGroupID)", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else { throw AppStoreConnectError.malformedResponse }
        return Self.mapBetaGroup(data)
    }

    private func get(path: String, query: [String: String]) async throws -> [String: Any] {
        try await send(method: "GET", path: path, query: query, jsonBody: nil)
    }

    private func send(method: String, path: String, query: [String: String], jsonBody: Any?) async throws -> [String: Any] {
        var headers = ["Authorization": "Bearer \(try jwtProvider())"]
        var bodyData: Data?
        if let jsonBody {
            headers["Content-Type"] = "application/json"
            bodyData = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        let response = try await transport.send(ASCRequest(method: method, path: path, queryItems: query, headers: headers, body: bodyData))
        guard (200..<300).contains(response.statusCode) else {
            throw AppStoreConnectError.badStatus(response.statusCode, response.body)
        }
        let data = Data(response.body.utf8)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func dataArray(_ json: [String: Any]) throws -> [[String: Any]] {
        guard let data = json["data"] as? [[String: Any]] else { throw AppStoreConnectError.malformedResponse }
        return data
    }

    private static func mapBetaGroup(_ item: [String: Any]) -> ASCBetaGroup {
        let attributes = item["attributes"] as? [String: Any]
        return ASCBetaGroup(
            id: item["id"] as? String ?? "",
            name: attributes?["name"] as? String ?? "",
            isInternalGroup: attributes?["isInternalGroup"] as? Bool ?? false,
            publicLinkEnabled: attributes?["publicLinkEnabled"] as? Bool ?? false,
            publicLink: attributes?["publicLink"] as? String,
            publicLinkLimit: attributes?["publicLinkLimit"] as? Int
        )
    }
}

public final class URLSessionASCTransport: ASCTransport {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: ASCRequest) async throws -> ASCTransportResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)!
        components.queryItems = request.queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }.sorted { $0.name < $1.name }
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = request.method
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        urlRequest.httpBody = request.body
        let (data, response) = try await session.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return ASCTransportResponse(statusCode: status, body: String(data: data, encoding: .utf8) ?? "")
    }
}

public final class StubASCTransport: ASCTransport {
    public private(set) var requests: [ASCRequest] = []
    private var responses: [ASCTransportResponse]

    public init(responses: [ASCTransportResponse]) {
        self.responses = responses
    }

    public func send(_ request: ASCRequest) async throws -> ASCTransportResponse {
        requests.append(request)
        return responses.removeFirst()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter AppStoreConnectClientTests
```

Expected: PASS with 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift
git commit -m "feat: add app store connect client"
```

---

### Task 6: Configuration Check Engine

**Files:**
- Create: `Sources/ProjPostCore/Checks/ConfigurationCheckEngine.swift`
- Create: `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`

**Interfaces:**
- Consumes: `ProjectProfile`, `AppleAccountProfile`, `AppStoreConnectClientProtocol`, `CommandRunning`
- Produces: `ConfigurationCheckEngine.run(project:account:) async -> [CheckResult]`
- Later UI consumes results to enable/disable upload.

- [ ] **Step 1: Write failing check engine tests**

Create `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`:

```swift
import XCTest
@testable import ProjPostCore

final class ConfigurationCheckEngineTests: XCTestCase {
    func testMissingBundleIDIsRed() async {
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(), appStoreConnect: FakeASCClient(app: nil, bundle: nil, builds: []))
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: nil, configuration: "Release", bundleID: nil, version: "1.0.0", buildNumber: "1", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertTrue(results.blocksUpload)
        XCTAssertEqual(results.first { $0.id == "bundle-id" }?.severity, .red)
    }

    func testExistingBuildNumberIsRed() async {
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(), appStoreConnect: FakeASCClient(app: ASCApp(id: "app1", name: "Demo", bundleID: "com.example.demo"), bundle: ASCBundleID(id: "bundle1", identifier: "com.example.demo", platform: "IOS"), builds: [ASCBuild(id: "build1", version: "7", processingState: "VALID")]))
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "7", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertEqual(results.first { $0.id == "build-number" }?.severity, .red)
    }
}

private struct PassingEnvironmentChecker: EnvironmentChecking {
    func checkXcode() async -> CheckResult {
        CheckResult(id: "xcode", title: "Xcode 可用", message: "已检测到 Xcode", severity: .green)
    }
}

private final class FakeASCClient: AppStoreConnectClientProtocol {
    let app: ASCApp?
    let bundle: ASCBundleID?
    let builds: [ASCBuild]

    init(app: ASCApp?, bundle: ASCBundleID?, builds: [ASCBuild]) {
        self.app = app
        self.bundle = bundle
        self.builds = builds
    }

    func fetchApp(bundleID: String) async throws -> ASCApp? { app }
    func fetchBundleID(identifier: String) async throws -> ASCBundleID? { bundle }
    func fetchBuilds(appID: String, buildNumber: String?) async throws -> [ASCBuild] { builds }
    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup] { [] }
    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {}
    func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup {
        ASCBetaGroup(id: betaGroupID, name: "外部公开测试", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/abc", publicLinkLimit: limit)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter ConfigurationCheckEngineTests
```

Expected: FAIL because `ConfigurationCheckEngine` and `EnvironmentChecking` do not exist.

- [ ] **Step 3: Implement check engine**

Create `Sources/ProjPostCore/Checks/ConfigurationCheckEngine.swift`:

```swift
import Foundation

public protocol EnvironmentChecking {
    func checkXcode() async -> CheckResult
}

public struct XcodeEnvironmentChecker: EnvironmentChecking {
    private let commandRunner: CommandRunning

    public init(commandRunner: CommandRunning = ProcessCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public func checkXcode() async -> CheckResult {
        do {
            let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: ["-version"]))
            guard result.exitCode == 0 else {
                return CheckResult(id: "xcode", title: "Xcode 不可用", message: result.stderr.isEmpty ? "请安装或选择 Xcode" : result.stderr, severity: .red)
            }
            return CheckResult(id: "xcode", title: "Xcode 可用", message: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), severity: .green)
        } catch {
            return CheckResult(id: "xcode", title: "Xcode 不可用", message: "请安装 Xcode 并确认命令行工具可用", severity: .red)
        }
    }
}

public final class ConfigurationCheckEngine {
    private let environment: EnvironmentChecking
    private let appStoreConnect: AppStoreConnectClientProtocol

    public init(environment: EnvironmentChecking, appStoreConnect: AppStoreConnectClientProtocol) {
        self.environment = environment
        self.appStoreConnect = appStoreConnect
    }

    public func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult] {
        var results: [CheckResult] = []
        results.append(await environment.checkXcode())

        guard let bundleID = project.bundleID, !bundleID.isEmpty else {
            results.append(CheckResult(id: "bundle-id", title: "Bundle ID 缺失", message: "请填写 Bundle ID 后重新检查", severity: .red))
            return results
        }

        do {
            let bundle = try await appStoreConnect.fetchBundleID(identifier: bundleID)
            results.append(bundle == nil
                ? CheckResult(id: "bundle-id", title: "Bundle ID 不存在", message: "当前 Apple 账号下没有找到 \(bundleID)", severity: .red)
                : CheckResult(id: "bundle-id", title: "Bundle ID 已找到", message: bundleID, severity: .green)
            )

            guard let app = try await appStoreConnect.fetchApp(bundleID: bundleID) else {
                results.append(CheckResult(id: "app", title: "App 不存在", message: "Bundle ID 未关联到 App Store Connect App", severity: .red))
                return results
            }
            results.append(CheckResult(id: "app", title: "App 匹配", message: app.name, severity: .green))

            if let teamID = project.teamID, let accountTeamID = account.teamID, teamID != accountTeamID {
                results.append(CheckResult(id: "team", title: "Team ID 不匹配", message: "项目为 \(teamID)，账号为 \(accountTeamID)", severity: .red))
            } else if project.teamID == nil || account.teamID == nil {
                results.append(CheckResult(id: "team", title: "Team ID 无法完全确认", message: "可以继续，但建议确认签名团队正确", severity: .yellow))
            } else {
                results.append(CheckResult(id: "team", title: "Team ID 匹配", message: project.teamID ?? "", severity: .green))
            }

            if let buildNumber = project.buildNumber, !buildNumber.isEmpty {
                let builds = try await appStoreConnect.fetchBuilds(appID: app.id, buildNumber: buildNumber)
                results.append(builds.isEmpty
                    ? CheckResult(id: "build-number", title: "Build Number 可用", message: buildNumber, severity: .green)
                    : CheckResult(id: "build-number", title: "Build Number 可能重复", message: "App Store Connect 已存在 build \(buildNumber)，请递增后再上传", severity: .red)
                )
            } else {
                results.append(CheckResult(id: "build-number", title: "Build Number 缺失", message: "请填写 Build Number", severity: .red))
            }
        } catch {
            results.append(CheckResult(id: "asc-api", title: "Apple 账号检查失败", message: String(describing: error), severity: .red))
        }

        return results
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter ConfigurationCheckEngineTests
```

Expected: PASS with 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/Checks/ConfigurationCheckEngine.swift Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift
git commit -m "feat: add configuration check engine"
```

---

### Task 7: Project Backup and Mutation

**Files:**
- Create: `Sources/ProjPostCore/Project/ProjectMutator.swift`
- Create: `Tests/ProjPostCoreTests/ProjectMutatorTests.swift`

**Interfaces:**
- Consumes: `ProjectProfile`
- Produces: `ProjectMutationRequest`
- Produces: `ProjectMutationPlan`
- Produces: `ProjectMutator.plan(request:) throws -> ProjectMutationPlan`
- Produces: `ProjectMutator.apply(_:) throws`
- Later UI uses the plan to show change summaries before writing.

- [ ] **Step 1: Write failing mutation tests**

Create `Tests/ProjPostCoreTests/ProjectMutatorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter ProjectMutatorTests
```

Expected: FAIL because mutation types do not exist.

- [ ] **Step 3: Implement mutation planning and backup-first apply**

Create `Sources/ProjPostCore/Project/ProjectMutator.swift`:

```swift
import Foundation

public struct ProjectMutationRequest: Equatable {
    public var projectRoot: URL
    public var pbxprojURL: URL
    public var infoPlistURL: URL?
    public var currentBundleID: String?
    public var newBundleID: String?
    public var currentVersion: String?
    public var newVersion: String?
    public var currentBuildNumber: String?
    public var newBuildNumber: String?

    public init(projectRoot: URL, pbxprojURL: URL, infoPlistURL: URL?, currentBundleID: String?, newBundleID: String?, currentVersion: String?, newVersion: String?, currentBuildNumber: String?, newBuildNumber: String?) {
        self.projectRoot = projectRoot
        self.pbxprojURL = pbxprojURL
        self.infoPlistURL = infoPlistURL
        self.currentBundleID = currentBundleID
        self.newBundleID = newBundleID
        self.currentVersion = currentVersion
        self.newVersion = newVersion
        self.currentBuildNumber = currentBuildNumber
        self.newBuildNumber = newBuildNumber
    }
}

public struct ProjectMutationChange: Equatable {
    public var summary: String
    public var oldValue: String?
    public var newValue: String?
}

public struct ProjectMutationPlan: Equatable {
    public var request: ProjectMutationRequest
    public var backupDirectory: URL
    public var filesToBackup: [URL]
    public var changes: [ProjectMutationChange]
}

public enum ProjectMutatorError: Error, Equatable {
    case missingPbxproj(URL)
    case noChanges
}

public final class ProjectMutator {
    private let fileSystem: FileSysteming
    private let backupRoot: URL

    public init(fileSystem: FileSysteming = LocalFileSystem(), backupRoot: URL) {
        self.fileSystem = fileSystem
        self.backupRoot = backupRoot
    }

    public func plan(request: ProjectMutationRequest) throws -> ProjectMutationPlan {
        guard fileSystem.fileExists(request.pbxprojURL) else {
            throw ProjectMutatorError.missingPbxproj(request.pbxprojURL)
        }

        var changes: [ProjectMutationChange] = []
        appendChange(&changes, label: "Bundle ID", old: request.currentBundleID, new: request.newBundleID)
        appendChange(&changes, label: "Version", old: request.currentVersion, new: request.newVersion)
        appendChange(&changes, label: "Build Number", old: request.currentBuildNumber, new: request.newBuildNumber)

        guard !changes.isEmpty else { throw ProjectMutatorError.noChanges }

        var files = [request.pbxprojURL]
        if let infoPlistURL = request.infoPlistURL, fileSystem.fileExists(infoPlistURL) {
            files.append(infoPlistURL)
        }

        let formatter = ISO8601DateFormatter()
        let folder = backupRoot.appendingPathComponent(formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-"), isDirectory: true)
        return ProjectMutationPlan(request: request, backupDirectory: folder, filesToBackup: files, changes: changes)
    }

    public func apply(_ plan: ProjectMutationPlan) throws {
        try backup(plan)
        var pbxData = try fileSystem.readData(plan.request.pbxprojURL)
        var pbxText = String(data: pbxData, encoding: .utf8) ?? ""
        if let old = plan.request.currentBundleID, let new = plan.request.newBundleID, old != new {
            pbxText = pbxText.replacingOccurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = \(old);", with: "PRODUCT_BUNDLE_IDENTIFIER = \(new);")
        }
        if let old = plan.request.currentVersion, let new = plan.request.newVersion, old != new {
            pbxText = pbxText.replacingOccurrences(of: "MARKETING_VERSION = \(old);", with: "MARKETING_VERSION = \(new);")
        }
        if let old = plan.request.currentBuildNumber, let new = plan.request.newBuildNumber, old != new {
            pbxText = pbxText.replacingOccurrences(of: "CURRENT_PROJECT_VERSION = \(old);", with: "CURRENT_PROJECT_VERSION = \(new);")
        }
        pbxData = Data(pbxText.utf8)
        try fileSystem.writeData(pbxData, to: plan.request.pbxprojURL)
    }

    private func backup(_ plan: ProjectMutationPlan) throws {
        try fileSystem.createDirectory(plan.backupDirectory)
        for file in plan.filesToBackup {
            let data = try fileSystem.readData(file)
            let backupFile = plan.backupDirectory.appendingPathComponent(file.lastPathComponent)
            try fileSystem.writeData(data, to: backupFile)
        }
        let summary = plan.changes.map(\.summary).joined(separator: "\n")
        try fileSystem.writeData(Data(summary.utf8), to: plan.backupDirectory.appendingPathComponent("changes.txt"))
    }

    private func appendChange(_ changes: inout [ProjectMutationChange], label: String, old: String?, new: String?) {
        guard let new, old != new else { return }
        changes.append(ProjectMutationChange(summary: "\(label): \(old ?? "-") -> \(new)", oldValue: old, newValue: new))
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --filter ProjectMutatorTests
```

Expected: PASS with 1 test.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/Project/ProjectMutator.swift Tests/ProjPostCoreTests/ProjectMutatorTests.swift
git commit -m "feat: plan and backup project mutations"
```

---

### Task 8: Upload Command Builder and Job Runner

**Files:**
- Create: `Sources/ProjPostCore/Upload/UploadCommandBuilder.swift`
- Create: `Sources/ProjPostCore/Upload/ExportOptionsPlistWriter.swift`
- Create: `Sources/ProjPostCore/Upload/UploadJobRunner.swift`
- Create: `Tests/ProjPostCoreTests/UploadCommandBuilderTests.swift`
- Create: `Tests/ProjPostCoreTests/ExportOptionsPlistWriterTests.swift`
- Create: `Tests/ProjPostCoreTests/UploadJobRunnerTests.swift`

**Interfaces:**
- Consumes: `ProjectProfile`, `AppleAccountProfile`, `CredentialVault`, `CommandRunning`
- Produces: `UploadCommandBuilder.archiveCommand(project:) throws -> Command`
- Produces: `UploadCommandBuilder.exportCommand(project:account:keyPath:archivePath:exportPath:) throws -> Command`
- Produces: `UploadCommandBuilder.uploadCommand(ipaPath:account:) -> Command`
- Produces: `ExportOptionsPlistWriter.write(teamID:to:) throws`
- Produces: `UploadJobRunner.start(request:) -> AsyncStream<UploadEvent>`

- [ ] **Step 1: Write failing upload command tests**

Create `Tests/ProjPostCoreTests/UploadCommandBuilderTests.swift`:

```swift
import XCTest
@testable import ProjPostCore

final class UploadCommandBuilderTests: XCTestCase {
    func testArchiveCommandUsesWorkspaceSchemeAndReleaseConfiguration() throws {
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: "/tmp/Demo/Demo.xcworkspace", projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "1", teamID: "ABCDE12345", selectedAccountID: nil, lastUpload: nil)
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
```

Create `Tests/ProjPostCoreTests/ExportOptionsPlistWriterTests.swift`:

```swift
import XCTest
@testable import ProjPostCore

final class ExportOptionsPlistWriterTests: XCTestCase {
    func testWriterCreatesAppStoreConnectExportOptions() throws {
        let fileSystem = MemoryFileSystem()
        let writer = ExportOptionsPlistWriter(fileSystem: fileSystem)
        let url = URL(fileURLWithPath: "/tmp/ExportOptions.plist")

        try writer.write(teamID: "ABCDE12345", to: url)

        let data = try XCTUnwrap(fileSystem.written[url])
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(object?["method"] as? String, "app-store-connect")
        XCTAssertEqual(object?["destination"] as? String, "export")
        XCTAssertEqual(object?["signingStyle"] as? String, "automatic")
        XCTAssertEqual(object?["teamID"] as? String, "ABCDE12345")
        XCTAssertEqual(object?["uploadSymbols"] as? Bool, true)
    }
}

private final class MemoryFileSystem: FileSysteming {
    var written: [URL: Data] = [:]

    func fileExists(_ url: URL) -> Bool { written[url] != nil }
    func contentsOfDirectory(_ url: URL) throws -> [String] { [] }
    func createDirectory(_ url: URL) throws {}
    func readData(_ url: URL) throws -> Data { written[url] ?? Data() }
    func writeData(_ data: Data, to url: URL) throws { written[url] = data }
}
```

Create `Tests/ProjPostCoreTests/UploadJobRunnerTests.swift`:

```swift
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
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: "/tmp/Demo/Demo.xcworkspace", projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "1", teamID: nil, selectedAccountID: nil, lastUpload: nil)
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
swift test --filter UploadCommandBuilderTests
swift test --filter ExportOptionsPlistWriterTests
swift test --filter UploadJobRunnerTests
```

Expected: FAIL because upload files do not exist.

- [ ] **Step 3: Implement upload command builder and local runner**

Create `Sources/ProjPostCore/Upload/UploadCommandBuilder.swift`:

```swift
import Foundation

public enum UploadCommandBuilderError: Error, Equatable {
    case missingScheme
    case missingWorkspaceOrProject
}

public struct UploadCommandBuilder {
    public init() {}

    public func archiveCommand(project: ProjectProfile, archivePath: URL) throws -> Command {
        guard let scheme = project.scheme else { throw UploadCommandBuilderError.missingScheme }
        var args = ["archive"]
        if let workspace = project.workspacePath {
            args += ["-workspace", workspace]
        } else if let projectFile = project.projectFilePath {
            args += ["-project", projectFile]
        } else {
            throw UploadCommandBuilderError.missingWorkspaceOrProject
        }
        args += [
            "-scheme", scheme,
            "-configuration", project.configuration,
            "-archivePath", archivePath.path,
            "-destination", "generic/platform=iOS",
            "-allowProvisioningUpdates"
        ]
        return Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: args, workingDirectory: URL(fileURLWithPath: project.projectPath))
    }

    public func exportCommand(project: ProjectProfile, account: AppleAccountProfile, keyPath: String, archivePath: URL, exportPath: URL, exportOptionsPlist: URL) -> Command {
        Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
            arguments: [
                "-exportArchive",
                "-archivePath", archivePath.path,
                "-exportPath", exportPath.path,
                "-exportOptionsPlist", exportOptionsPlist.path,
                "-allowProvisioningUpdates",
                "-authenticationKeyIssuerID", account.issuerID,
                "-authenticationKeyID", account.keyID,
                "-authenticationKeyPath", keyPath
            ],
            workingDirectory: URL(fileURLWithPath: project.projectPath)
        )
    }

    public func uploadCommand(ipaPath: URL, account: AppleAccountProfile) -> Command {
        Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: [
                "altool",
                "--upload-app",
                "-f", ipaPath.path,
                "-t", "ios",
                "--apiKey", account.keyID,
                "--apiIssuer", account.issuerID
            ]
        )
    }
}
```

Create `Sources/ProjPostCore/Upload/ExportOptionsPlistWriter.swift`:

```swift
import Foundation

public struct ExportOptionsPlistWriter {
    private let fileSystem: FileSysteming

    public init(fileSystem: FileSysteming = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func write(teamID: String?, to url: URL) throws {
        var plist: [String: Any] = [
            "destination": "export",
            "method": "app-store-connect",
            "signingStyle": "automatic",
            "stripSwiftSymbols": true,
            "uploadSymbols": true
        ]
        if let teamID, !teamID.isEmpty {
            plist["teamID"] = teamID
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try fileSystem.writeData(data, to: url)
    }
}
```

Create `Sources/ProjPostCore/Upload/UploadJobRunner.swift`:

```swift
import Foundation

public struct UploadEvent: Equatable {
    public var step: UploadStep
    public var message: String
    public var succeeded: Bool
}

public final class UploadJobRunner {
    private let commandRunner: CommandRunning
    private let commandBuilder: UploadCommandBuilder
    private let exportOptionsWriter: ExportOptionsPlistWriter

    public init(commandRunner: CommandRunning, commandBuilder: UploadCommandBuilder, exportOptionsWriter: ExportOptionsPlistWriter = ExportOptionsPlistWriter()) {
        self.commandRunner = commandRunner
        self.commandBuilder = commandBuilder
        self.exportOptionsWriter = exportOptionsWriter
    }

    public func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile, keyPath: String) async throws -> [UploadEvent] {
        let buildDir = URL(fileURLWithPath: project.projectPath).appendingPathComponent("build", isDirectory: true)
        let archivePath = buildDir.appendingPathComponent("\(project.name).xcarchive")
        let exportPath = buildDir.appendingPathComponent("export", isDirectory: true)
        let exportOptions = buildDir.appendingPathComponent("ExportOptions.plist")
        let ipaPath = exportPath.appendingPathComponent("\(project.name).ipa")

        var events: [UploadEvent] = []
        let archive = try await commandRunner.run(try commandBuilder.archiveCommand(project: project, archivePath: archivePath))
        try append(result: archive, step: .archive, to: &events)

        try exportOptionsWriter.write(teamID: project.teamID, to: exportOptions)
        let export = try await commandRunner.run(commandBuilder.exportCommand(project: project, account: account, keyPath: keyPath, archivePath: archivePath, exportPath: exportPath, exportOptionsPlist: exportOptions))
        try append(result: export, step: .exportIPA, to: &events)

        let upload = try await commandRunner.run(commandBuilder.uploadCommand(ipaPath: ipaPath, account: account))
        try append(result: upload, step: .upload, to: &events)

        return events
    }

    private func append(result: CommandResult, step: UploadStep, to events: inout [UploadEvent]) throws {
        let message = result.stdout.isEmpty ? result.stderr : result.stdout
        let succeeded = result.exitCode == 0
        events.append(UploadEvent(step: step, message: message.trimmingCharacters(in: .whitespacesAndNewlines), succeeded: succeeded))
        if !succeeded {
            throw UploadJobRunnerError.commandFailed(step: step, message: message)
        }
    }
}

public enum UploadJobRunnerError: Error, Equatable {
    case commandFailed(step: UploadStep, message: String)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
swift test --filter UploadCommandBuilderTests
swift test --filter UploadJobRunnerTests
```

Expected: PASS for both test classes.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/Upload Tests/ProjPostCoreTests/UploadCommandBuilderTests.swift Tests/ProjPostCoreTests/UploadJobRunnerTests.swift
git commit -m "feat: build upload command workflow"
```

---

### Task 9: SwiftUI ViewModels and Main UI

**Files:**
- Create: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Create: `Sources/ProjPostApp/Views/ProjectListView.swift`
- Create: `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- Create: `Sources/ProjPostApp/Views/CheckResultsView.swift`
- Create: `Sources/ProjPostApp/Views/UploadProgressView.swift`
- Modify: `Sources/ProjPostApp/Views/ContentView.swift`
- Create: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes: `ProjectProfileStore`, `ProjectScanner`, `ConfigurationCheckEngine`, `UploadJobRunner`
- Produces: `AppViewModel.projects`, `selectedProject`, `checkResults`, `uploadState`, `uploadEvents`
- UI surfaces the sketch structure: left project cards, right project detail, check panel, TestFlight card, logs.

- [ ] **Step 1: Write failing ViewModel state test**

Create `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`:

```swift
import XCTest
@testable import ProjPostCore

final class AppViewModelStateTests: XCTestCase {
    func testSelectingProjectUpdatesSelectedProject() {
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: nil, configuration: "Release", bundleID: nil, version: nil, buildNumber: nil, teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let viewModel = AppViewModel(projects: [project])

        viewModel.selectProject(project.id)

        XCTAssertEqual(viewModel.selectedProject?.id, project.id)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter AppViewModelStateTests
```

Expected: FAIL because `AppViewModel` does not exist.

- [ ] **Step 3: Implement ViewModel and views**

Create `Sources/ProjPostCore/AppState/AppViewModel.swift`:

```swift
import Combine
import Foundation

public final class AppViewModel: ObservableObject {
    @Published public private(set) var projects: [ProjectProfile]
    @Published public private(set) var selectedProjectID: UUID?
    @Published public var checkResults: [CheckResult] = []
    @Published public var uploadState: UploadJobState = .idle
    @Published public var uploadEvents: [UploadEvent] = []

    public init(projects: [ProjectProfile] = []) {
        self.projects = projects
        self.selectedProjectID = projects.first?.id
    }

    public var selectedProject: ProjectProfile? {
        projects.first { $0.id == selectedProjectID }
    }

    public func selectProject(_ id: UUID) {
        selectedProjectID = id
    }

    public func addProject(_ project: ProjectProfile) {
        projects.append(project)
        selectedProjectID = project.id
    }
}
```

Create `Sources/ProjPostApp/Views/ProjectListView.swift`:

```swift
import ProjPostCore
import SwiftUI

struct ProjectListView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("项目列表")
                .font(.title2.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                ForEach(viewModel.projects) { project in
                    Button {
                        viewModel.selectProject(project.id)
                    } label: {
                        VStack(spacing: 8) {
                            Text(project.name)
                                .font(.headline)
                            Text(project.versionDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(project.statusLabel)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(width: 128, height: 112)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    let project = ProjectProfile(name: "新项目", projectPath: "", workspacePath: nil, projectFilePath: nil, scheme: nil, configuration: "Release", bundleID: nil, version: nil, buildNumber: nil, teamID: nil, selectedAccountID: nil, lastUpload: nil)
                    viewModel.addProject(project)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .frame(width: 128, height: 112)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(24)
    }
}
```

Create `Sources/ProjPostApp/Views/ProjectDetailView.swift`:

```swift
import ProjPostCore
import SwiftUI

struct ProjectDetailView: View {
    let project: ProjectProfile?
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(project?.name ?? "选择或添加项目")
                    .font(.title.bold())

                GroupBox("项目基础配置") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        row("Bundle ID", project?.bundleID ?? "")
                        row("Version", project?.version ?? "")
                        row("Build Number", project?.buildNumber ?? "")
                        row("Scheme", project?.scheme ?? "")
                        row("Team ID", project?.teamID ?? "")
                    }
                    .padding(8)
                }

                GroupBox("Apple 账号") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(".p8 已导入后会保存到本机 Keychain")
                            .foregroundStyle(.secondary)
                        TextField("Key ID", text: .constant(""))
                        TextField("Issuer ID", text: .constant(""))
                    }
                    .padding(8)
                }

                CheckResultsView(results: viewModel.checkResults)

                GroupBox("TestFlight 分发") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("内部测试人员")
                        Text("公开测试链接")
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                UploadProgressView(state: viewModel.uploadState, events: viewModel.uploadEvents)
            }
            .padding(24)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            TextField(title, text: .constant(value))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
        }
    }
}
```

Create `Sources/ProjPostApp/Views/CheckResultsView.swift`:

```swift
import ProjPostCore
import SwiftUI

struct CheckResultsView: View {
    let results: [CheckResult]

    var body: some View {
        GroupBox("配置检查") {
            VStack(alignment: .leading, spacing: 8) {
                if results.isEmpty {
                    Text("点击检查配置后显示结果")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { result in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(color(for: result.severity))
                                .frame(width: 10, height: 10)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title).font(.headline)
                                Text(result.message).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func color(for severity: CheckSeverity) -> Color {
        switch severity {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}
```

Create `Sources/ProjPostApp/Views/UploadProgressView.swift`:

```swift
import ProjPostCore
import SwiftUI

struct UploadProgressView: View {
    let state: UploadJobState
    let events: [UploadEvent]

    var body: some View {
        GroupBox("上传进度") {
            VStack(alignment: .leading, spacing: 10) {
                Text(stateText)
                    .font(.headline)
                ForEach(events.indices, id: \.self) { index in
                    let event = events[index]
                    HStack {
                        Image(systemName: event.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(event.succeeded ? .green : .red)
                        Text(event.step.rawValue)
                        Spacer()
                    }
                }
                Text(events.map(\.message).joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(8)
        }
    }

    private var stateText: String {
        switch state {
        case .idle: return "等待上传"
        case .running(let step): return "正在执行：\(step.rawValue)"
        case .succeeded(let message): return message
        case .failed(let message): return message
        case .cancelled: return "已取消"
        }
    }
}
```

Modify `Sources/ProjPostApp/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationSplitView {
            ProjectListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 360, ideal: 420)
        } detail: {
            ProjectDetailView(project: viewModel.selectedProject, viewModel: viewModel)
        }
    }
}
```

- [ ] **Step 4: Run tests and launch app**

Run:

```bash
swift test --filter AppViewModelStateTests
swift run ProjPostApp
```

Expected: test PASS; app launches a two-pane window with project list and project detail areas.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Sources/ProjPostApp Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat: add mac app shell"
```

---

### Task 10: Manual Test Checklist and Real Account Trial

**Files:**
- Create: `docs/manual-test-checklist.md`

**Interfaces:**
- Consumes: completed local MVP.
- Produces: repeatable manual validation script for paid Apple Developer account testing.

- [ ] **Step 1: Create the manual checklist**

Create `docs/manual-test-checklist.md`:

```markdown
# ProjPost Manual Test Checklist

## Local Environment

- [ ] Open the Mac app.
- [ ] Confirm Xcode version appears in configuration checks.
- [ ] Confirm missing Xcode or command-line tool failure is shown as a red issue on a machine without valid tools.

## Apple Account

- [ ] Import a real `.p8` file.
- [ ] Enter Key ID and Issuer ID.
- [ ] Confirm the private key is stored in Keychain and raw key content is not displayed in the UI.
- [ ] Run account validation.
- [ ] Confirm invalid Key ID or Issuer ID shows a red issue.

## Project Checks

- [ ] Add a real iOS project.
- [ ] Confirm workspace or project file is detected.
- [ ] Confirm schemes are detected.
- [ ] Confirm Bundle ID, Version, Build Number, and Team ID are read.
- [ ] Run configuration check with a matching Bundle ID.
- [ ] Run configuration check with a wrong Bundle ID and confirm a red issue.
- [ ] Increment Build Number and confirm duplicate-build warning disappears.

## Project Mutation

- [ ] Change Bundle ID, Version, or Build Number in the UI.
- [ ] Confirm the change summary is readable.
- [ ] Apply changes.
- [ ] Confirm backup files exist.
- [ ] Confirm Xcode project settings changed as expected.

## Upload

- [ ] Start upload.
- [ ] Confirm progress shows archive, export, validate, upload, Apple processing, TestFlight assignment.
- [ ] Confirm detailed logs are available.
- [ ] Confirm upload failure preserves enough log detail to diagnose the cause.

## TestFlight

- [ ] Assign build to an internal tester group.
- [ ] Assign build to an external beta group.
- [ ] Enable or read public link for the external beta group.
- [ ] Copy public link.
- [ ] Confirm a non-organization Apple ID only sees builds assigned to the external group.
- [ ] Confirm an organization/internal tester account sees internal builds according to Apple TestFlight permissions.
```

- [ ] **Step 2: Commit**

```bash
git add docs/manual-test-checklist.md
git commit -m "docs: add manual test checklist"
```

---

## Self-Review Notes

- Spec coverage: The plan covers project profiles, Keychain credential storage, configuration checks, project backups/mutations, upload commands, App Store Connect API access, TestFlight public link handling, UI shell, and manual validation.
- V1 scope control: App Store formal review automation, cloud credential storage, iPhone/iPad build execution, and CI worker pools remain outside this plan.
- Push status: Local git history can be pushed after SSH access to `git@github.com:jrlingyin888/ProjPost.git` is fixed or the remote is switched to an authenticated HTTPS URL.
