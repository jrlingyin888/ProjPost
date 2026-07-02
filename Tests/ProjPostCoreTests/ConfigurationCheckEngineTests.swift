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
        let fakeASC = FakeASCClient(
            app: ASCApp(id: "app1", name: "Demo", bundleID: "com.example.demo"),
            bundle: ASCBundleID(id: "bundle1", identifier: "com.example.demo", platform: "IOS"),
            builds: [ASCBuild(id: "build1", version: "7", processingState: "VALID")]
        )
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(), appStoreConnect: fakeASC)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "7", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertEqual(fakeASC.fetchBuildsAppID, "app1")
        XCTAssertEqual(fakeASC.fetchBuildsBuildNumber, "7")
        XCTAssertEqual(results.first { $0.id == "build-number" }?.severity, .red)
    }

    func testASCFailureEmitsRedAPIResultAndBlocksUpload() async {
        let fakeASC = FakeASCClient(
            app: ASCApp(id: "app1", name: "Demo", bundleID: "com.example.demo"),
            bundle: ASCBundleID(id: "bundle1", identifier: "com.example.demo", platform: "IOS"),
            builds: [],
            fetchBuildsError: TestError.unavailable
        )
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(), appStoreConnect: fakeASC)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "7", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertTrue(results.blocksUpload)
        XCTAssertEqual(results.first { $0.id == "asc-api" }?.severity, .red)
        XCTAssertNil(results.first { $0.id == "build-number" })
    }

    func testXcodeEnvironmentCheckerReturnsGreenOnSuccessAndRedOnFailure() async {
        let successRunner = FakeCommandRunner(result: CommandResult(exitCode: 0, stdout: "Xcode 15.4\nBuild version 15F31d\n", stderr: ""))
        let successChecker = XcodeEnvironmentChecker(commandRunner: successRunner)

        let successResult = await successChecker.checkXcode()

        XCTAssertEqual(successRunner.commands.count, 1)
        XCTAssertEqual(successRunner.commands.first?.executableURL.path, "/usr/bin/xcodebuild")
        XCTAssertEqual(successRunner.commands.first?.arguments, ["-version"])
        XCTAssertEqual(successResult.severity, .green)

        let failureRunner = FakeCommandRunner(result: CommandResult(exitCode: 1, stdout: "", stderr: "xcodebuild: command not found"))
        let failureChecker = XcodeEnvironmentChecker(commandRunner: failureRunner)

        let failureResult = await failureChecker.checkXcode()

        XCTAssertEqual(failureRunner.commands.count, 1)
        XCTAssertEqual(failureResult.severity, .red)
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
    let fetchBuildsError: Error?
    private(set) var fetchBuildsAppID: String?
    private(set) var fetchBuildsBuildNumber: String?

    init(app: ASCApp?, bundle: ASCBundleID?, builds: [ASCBuild], fetchBuildsError: Error? = nil) {
        self.app = app
        self.bundle = bundle
        self.builds = builds
        self.fetchBuildsError = fetchBuildsError
    }

    func fetchApp(bundleID: String) async throws -> ASCApp? { app }
    func fetchBundleID(identifier: String) async throws -> ASCBundleID? { bundle }
    func fetchBuilds(appID: String, buildNumber: String?) async throws -> [ASCBuild] {
        fetchBuildsAppID = appID
        fetchBuildsBuildNumber = buildNumber
        if let fetchBuildsError {
            throw fetchBuildsError
        }
        return builds
    }
    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup] { [] }
    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {}
    func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup {
        ASCBetaGroup(id: betaGroupID, name: "外部公开测试", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/abc", publicLinkLimit: limit)
    }
}

private final class FakeCommandRunner: CommandRunning {
    let result: CommandResult
    private(set) var commands: [Command] = []

    init(result: CommandResult) {
        self.result = result
    }

    func run(_ command: Command) async throws -> CommandResult {
        commands.append(command)
        return result
    }
}

private enum TestError: Error {
    case unavailable
}
