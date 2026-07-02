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
