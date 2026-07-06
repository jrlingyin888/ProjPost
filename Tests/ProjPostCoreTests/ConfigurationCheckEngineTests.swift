import XCTest
@testable import ProjPostCore

final class ConfigurationCheckEngineTests: XCTestCase {
    func testMissingBundleIDIsRed() async {
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(language: .english), appStoreConnect: FakeASCClient(app: nil, bundle: nil, builds: []), language: .english)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: nil, configuration: "Release", bundleID: nil, version: "1.0.0", buildNumber: "1", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertTrue(results.blocksUpload)
        XCTAssertEqual(results.first { $0.id == "bundle-id" }?.severity, .red)
        XCTAssertEqual(results.first { $0.id == "bundle-id" }?.title, "Bundle ID Missing")
    }

    func testMissingBundleIDCanReturnSimplifiedChinese() async {
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(language: .simplifiedChinese), appStoreConnect: FakeASCClient(app: nil, bundle: nil, builds: []), language: .simplifiedChinese)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: nil, configuration: "Release", bundleID: nil, version: "1.0.0", buildNumber: "1", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertEqual(results.first { $0.id == "bundle-id" }?.title, "Bundle ID 缺失")
        XCTAssertEqual(results.first { $0.id == "bundle-id" }?.message, "请填写 Bundle ID 后重新检查")
    }

    func testExistingBuildNumberForSameVersionIsRed() async {
        let fakeASC = FakeASCClient(
            app: ASCApp(id: "app1", name: "Demo", bundleID: "com.example.demo"),
            bundle: ASCBundleID(id: "bundle1", identifier: "com.example.demo", platform: "IOS"),
            builds: [ASCBuild(id: "build1", version: "7", processingState: "VALID")]
        )
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(language: .english), appStoreConnect: fakeASC)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "7", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertEqual(fakeASC.fetchBuildsAppID, "app1")
        XCTAssertEqual(fakeASC.fetchBuildsBuildNumber, "7")
        XCTAssertEqual(fakeASC.fetchBuildsAppVersion, "1.0.0")
        XCTAssertEqual(results.first { $0.id == "build-number" }?.severity, .red)
    }

    func testExistingBuildNumberForDifferentVersionDoesNotBlockUpload() async {
        let fakeASC = FakeASCClient(
            app: ASCApp(id: "app1", name: "Demo", bundleID: "com.example.demo"),
            bundle: ASCBundleID(id: "bundle1", identifier: "com.example.demo", platform: "IOS"),
            builds: []
        )
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(language: .english), appStoreConnect: fakeASC)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.2.6", buildNumber: "1", teamID: "TEAM123", selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertEqual(fakeASC.fetchBuildsAppID, "app1")
        XCTAssertEqual(fakeASC.fetchBuildsBuildNumber, "1")
        XCTAssertEqual(fakeASC.fetchBuildsAppVersion, "1.2.6")
        XCTAssertFalse(results.blocksUpload)
        XCTAssertEqual(results.first { $0.id == "build-number" }?.severity, .green)
    }

    func testASCFailureEmitsRedAPIResultAndBlocksUpload() async {
        let fakeASC = FakeASCClient(
            app: ASCApp(id: "app1", name: "Demo", bundleID: "com.example.demo"),
            bundle: ASCBundleID(id: "bundle1", identifier: "com.example.demo", platform: "IOS"),
            builds: [],
            fetchBuildsError: TestError.unavailable
        )
        let engine = ConfigurationCheckEngine(environment: PassingEnvironmentChecker(language: .english), appStoreConnect: fakeASC)
        let project = ProjectProfile(name: "Demo", projectPath: "/tmp/Demo", workspacePath: nil, projectFilePath: nil, scheme: "Demo", configuration: "Release", bundleID: "com.example.demo", version: "1.0.0", buildNumber: "7", teamID: nil, selectedAccountID: nil, lastUpload: nil)
        let account = AppleAccountProfile(displayName: "Company", keyID: "ABC123DEF4", issuerID: "issuer", teamID: nil, lastVerifiedAt: nil)

        let results = await engine.run(project: project, account: account)

        XCTAssertTrue(results.blocksUpload)
        XCTAssertEqual(results.first { $0.id == "asc-api" }?.severity, .red)
        XCTAssertNil(results.first { $0.id == "build-number" })
    }

    func testXcodeEnvironmentCheckerReturnsGreenOnSuccessAndRedOnFailure() async {
        let successRunner = FakeCommandRunner(result: CommandResult(exitCode: 0, stdout: "Xcode 15.4\nBuild version 15F31d\n", stderr: ""))
        let successChecker = XcodeEnvironmentChecker(commandRunner: successRunner, language: .english)

        let successResult = await successChecker.checkXcode()

        XCTAssertEqual(successRunner.commands.count, 2)
        XCTAssertEqual(successRunner.commands.first?.executableURL.path, "/usr/bin/xcodebuild")
        XCTAssertEqual(successRunner.commands.first?.arguments, ["-version"])
        XCTAssertEqual(successRunner.commands.last?.executableURL.path, "/usr/bin/env")
        XCTAssertEqual(successRunner.commands.last?.arguments, ["rsync", "--version"])
        XCTAssertEqual(successResult.severity, .green)

        let failureRunner = FakeCommandRunner(result: CommandResult(exitCode: 1, stdout: "", stderr: "xcodebuild: command not found"))
        let failureChecker = XcodeEnvironmentChecker(commandRunner: failureRunner, language: .english)

        let failureResult = await failureChecker.checkXcode()

        XCTAssertEqual(failureRunner.commands.count, 1)
        XCTAssertEqual(failureResult.severity, .red)
    }

    func testXcodeEnvironmentCheckerReturnsRedWhenRsyncIsUnavailable() async {
        let runner = QueueCommandRunner(results: [
            CommandResult(exitCode: 0, stdout: "Xcode 26.6\nBuild version 17F113\n", stderr: ""),
            CommandResult(exitCode: 127, stdout: "", stderr: "env: rsync: No such file or directory")
        ])
        let checker = XcodeEnvironmentChecker(commandRunner: runner, language: .simplifiedChinese)

        let result = await checker.checkXcode()

        XCTAssertEqual(result.id, "rsync")
        XCTAssertEqual(result.severity, .red)
        XCTAssertEqual(result.title, "rsync 不可用")
        XCTAssertEqual(runner.commands.map { $0.executableURL.path }, ["/usr/bin/xcodebuild", "/usr/bin/env"])
        XCTAssertEqual(runner.commands.last?.arguments, ["rsync", "--version"])
    }
}

private struct PassingEnvironmentChecker: EnvironmentChecking {
    var language: AppLanguage

    func checkXcode() async -> CheckResult {
        CheckResult(id: "xcode", title: AppStrings(language: language).configurationCheckXcodeAvailableTitle, message: "Detected Xcode", severity: .green)
    }
}

private final class FakeASCClient: AppStoreConnectClientProtocol {
    let app: ASCApp?
    let bundle: ASCBundleID?
    let builds: [ASCBuild]
    let fetchBuildsError: Error?
    private(set) var fetchBuildsAppID: String?
    private(set) var fetchBuildsBuildNumber: String?
    private(set) var fetchBuildsAppVersion: String?

    init(app: ASCApp?, bundle: ASCBundleID?, builds: [ASCBuild], fetchBuildsError: Error? = nil) {
        self.app = app
        self.bundle = bundle
        self.builds = builds
        self.fetchBuildsError = fetchBuildsError
    }

    func fetchApp(bundleID: String) async throws -> ASCApp? { app }
    func fetchBundleID(identifier: String) async throws -> ASCBundleID? { bundle }
    func fetchBuilds(appID: String, appVersion: String?, buildNumber: String?) async throws -> [ASCBuild] {
        fetchBuildsAppID = appID
        fetchBuildsBuildNumber = buildNumber
        fetchBuildsAppVersion = appVersion
        if let fetchBuildsError {
            throw fetchBuildsError
        }
        return builds
    }
    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup] { [] }
    func fetchBuildsForBetaGroup(betaGroupID: String) async throws -> [ASCBuild] { [] }
    func fetchBetaReviewSubmission(buildID: String) async throws -> ASCBetaReviewSubmission? { nil }
    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {}
    func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup {
        ASCBetaGroup(id: betaGroupID, name: "外部公开测试", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/abc", publicLinkLimit: limit)
    }

    func submitBetaReview(buildID: String) async throws -> ASCBetaReviewSubmission {
        ASCBetaReviewSubmission(id: "submission-\(buildID)", betaReviewState: "IN_REVIEW")
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

private final class QueueCommandRunner: CommandRunning {
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
