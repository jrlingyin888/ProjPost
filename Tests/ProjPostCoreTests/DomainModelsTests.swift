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

    func testReviewPhaseResolvesFromSubmissionAndVersionState() {
        XCTAssertEqual(AppStoreReviewPhase.resolve(snapshot: nil), .noVersion)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "PREPARE_FOR_SUBMISSION", submissionState: nil), .editable)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "REJECTED", submissionState: nil), .editable)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "PREPARE_FOR_SUBMISSION", submissionState: "WAITING_FOR_REVIEW"), .inReview)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "IN_REVIEW", submissionState: nil), .inReview)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "PREPARE_FOR_SUBMISSION", submissionState: "CANCELING"), .canceling)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "PENDING_DEVELOPER_RELEASE", submissionState: nil), .pendingDeveloperRelease)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "PENDING_APPLE_RELEASE", submissionState: nil), .releasing)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "READY_FOR_SALE", submissionState: nil), .live)
        XCTAssertEqual(AppStoreReviewPhase(versionState: "REPLACED_WITH_NEW_VERSION", submissionState: nil), .replaced)
    }

    private func makeReviewSnapshot(
        builds: [AppStoreReviewBuildOption] = [AppStoreReviewBuildOption(id: "b1", buildNumber: "1", processingState: "VALID", isBound: false)],
        selectedBuildID: String? = "b1",
        versionState: String? = "PREPARE_FOR_SUBMISSION",
        reviewDetail: ASCAppStoreReviewDetail? = ASCAppStoreReviewDetail(id: "d", contactFirstName: "A", contactLastName: "B", contactPhone: "1", contactEmail: "a@b.c", demoAccountName: nil, demoAccountPassword: nil, demoAccountRequired: false, notes: nil),
        localizations: [ASCAppStoreVersionLocalization] = [ASCAppStoreVersionLocalization(id: "l", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: "新内容")],
        screenshotSets: [AppStoreReviewScreenshotSet] = [AppStoreReviewScreenshotSet(id: "s", localizationID: "l", locale: "zh-Hans", screenshotDisplayType: "APP_IPHONE_65", screenshots: [ASCAppScreenshot(id: "sc", fileName: "a.png", fileSize: 1, imageURLTemplate: nil, width: 1, height: 1, assetDeliveryState: "COMPLETE")])]
    ) -> AppStoreReviewSnapshot {
        AppStoreReviewSnapshot(
            appID: "app", appStoreVersionID: "v", versionString: "1.2.6", versionState: versionState, releaseType: "MANUAL",
            selectedBuildID: selectedBuildID, boundBuildID: nil, builds: builds, reviewDetail: reviewDetail,
            localizations: localizations, screenshotSets: screenshotSets, reviewSubmissionState: nil
        )
    }

    func testReadinessAllGreenDoesNotBlock() {
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot())
        XCTAssertFalse(AppStoreReviewReadiness.blocks(items))
        XCTAssertEqual(items.first(where: { $0.kind == .buildValid })?.severity, .green)
        XCTAssertEqual(items.first(where: { $0.kind == .screenshotsPresent })?.severity, .green)
    }

    func testReadinessMissingBuildBlocksRed() {
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(selectedBuildID: nil))
        XCTAssertTrue(AppStoreReviewReadiness.blocks(items))
        XCTAssertEqual(items.first(where: { $0.kind == .buildValid })?.severity, .red)
    }

    func testReadinessProcessingBuildBlocksRed() {
        let snapshot = makeReviewSnapshot(builds: [AppStoreReviewBuildOption(id: "b1", buildNumber: "1", processingState: "PROCESSING", isBound: false)])
        let items = AppStoreReviewReadiness.evaluate(snapshot: snapshot)
        XCTAssertEqual(items.first(where: { $0.kind == .buildValid })?.severity, .red)
    }

    func testReadinessIncompleteContactBlocksRed() {
        let detail = ASCAppStoreReviewDetail(id: "d", contactFirstName: "A", contactLastName: nil, contactPhone: nil, contactEmail: "a@b.c", demoAccountName: nil, demoAccountPassword: nil, demoAccountRequired: false, notes: nil)
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(reviewDetail: detail))
        XCTAssertEqual(items.first(where: { $0.kind == .reviewContactComplete })?.severity, .red)
    }

    func testReadinessMissingWhatsNewOnUpdateVersionBlocksRed() {
        let locs = [ASCAppStoreVersionLocalization(id: "l", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: "  ")]
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(localizations: locs))
        XCTAssertEqual(items.first(where: { $0.kind == .whatsNewFilled })?.severity, .red)
    }

    func testReadinessFirstVersionWithoutWhatsNewIsGreen() {
        let locs = [ASCAppStoreVersionLocalization(id: "l", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: nil)]
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(localizations: locs))
        XCTAssertEqual(items.first(where: { $0.kind == .whatsNewFilled })?.severity, .green)
    }

    func testReadinessPartialWhatsNewWarnsYellowNotBlock() {
        let locs = [
            ASCAppStoreVersionLocalization(id: "l1", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: "新内容"),
            ASCAppStoreVersionLocalization(id: "l2", locale: "en-US", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: "   ")
        ]
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(localizations: locs))
        let item = items.first(where: { $0.kind == .whatsNewFilled })
        XCTAssertEqual(item?.severity, .yellow)
        XCTAssertEqual(item?.detail, "en-US")
        XCTAssertFalse(AppStoreReviewReadiness.blocks(items))
    }

    func testReadinessMissingScreenshotsWarnsYellowNotBlock() {
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(screenshotSets: []))
        XCTAssertEqual(items.first(where: { $0.kind == .screenshotsPresent })?.severity, .yellow)
        XCTAssertFalse(AppStoreReviewReadiness.blocks(items))
    }

    func testReadinessExportComplianceStateBlocksRed() {
        let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(versionState: "WAITING_FOR_EXPORT_COMPLIANCE"))
        XCTAssertEqual(items.first(where: { $0.kind == .exportCompliance })?.severity, .red)
    }
}
