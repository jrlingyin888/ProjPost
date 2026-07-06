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
        XCTAssertEqual(profile.statusLabel(language: .english), "Not Configured")
        XCTAssertEqual(profile.statusLabel(language: .simplifiedChinese), "未配置")
    }

    func testCheckSeverityBlocksUploadOnlyForRedResults() {
        let red = CheckResult(id: "bundle", title: "Bundle ID 不存在", message: "请修改 Bundle ID", severity: .red)
        let yellow = CheckResult(id: "team", title: "Team ID 无法确认", message: "可以继续但建议确认", severity: .yellow)

        XCTAssertTrue([red, yellow].blocksUpload)
        XCTAssertFalse([yellow].blocksUpload)
    }
}
