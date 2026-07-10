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

    func testFetchBuildsForBetaGroupMapsAssociatedBuilds() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":[{"id":"build-123","type":"builds","attributes":{"version":"1","processingState":"VALID","betaReviewState":"APPROVED"}},{"id":"build-456","type":"builds","attributes":{"version":"2","processingState":"PROCESSING","betaReviewState":"WAITING_FOR_REVIEW"}}]}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let builds = try await client.fetchBuildsForBetaGroup(betaGroupID: "group-123")

        XCTAssertEqual(builds, [
            ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED"),
            ASCBuild(id: "build-456", version: "2", processingState: "PROCESSING", betaReviewState: "WAITING_FOR_REVIEW")
        ])
        XCTAssertEqual(transport.requests.first?.path, "/v1/betaGroups/group-123/builds")
    }

    func testFetchBetaReviewSubmissionForBuildMapsReviewState() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":{"id":"submission-123","type":"betaAppReviewSubmissions","attributes":{"betaReviewState":"WAITING_FOR_REVIEW"}}}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let submission = try await client.fetchBetaReviewSubmission(buildID: "build-123")

        XCTAssertEqual(submission, ASCBetaReviewSubmission(id: "submission-123", betaReviewState: "WAITING_FOR_REVIEW"))
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/v1/builds/build-123/betaAppReviewSubmission")
        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
    }

    func testFetchBuildsFiltersByAppVersionAndBuildNumber() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":[{"id":"build1","type":"builds","attributes":{"version":"1","processingState":"VALID","betaReviewState":"WAITING_FOR_REVIEW"}}]}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let builds = try await client.fetchBuilds(appID: "123", appVersion: "1.2.6", buildNumber: "1")

        XCTAssertEqual(builds, [
            ASCBuild(id: "build1", version: "1", processingState: "VALID", betaReviewState: "WAITING_FOR_REVIEW")
        ])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.path, "/v1/builds")
        XCTAssertEqual(request.queryItems["filter[app]"], "123")
        XCTAssertEqual(request.queryItems["filter[preReleaseVersion.version]"], "1.2.6")
        XCTAssertEqual(request.queryItems["filter[version]"], "1")
    }

    func testAddBuildSucceedsOnNoContentResponse() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 204, body: "")
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        try await client.addBuild("build-123", toBetaGroup: "group-456")

        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/v1/betaGroups/group-456/relationships/builds")
        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(String(data: try XCTUnwrap(request.body), encoding: .utf8), #"{"data":[{"id":"build-123","type":"builds"}]}"#)
    }

    func testSubmitBetaReviewCreatesSubmissionForBuild() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 201, body: #"{"data":{"id":"submission-123","type":"betaAppReviewSubmissions","attributes":{"betaReviewState":"IN_REVIEW"}}}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let submission = try await client.submitBetaReview(buildID: "build-123")

        XCTAssertEqual(submission.id, "submission-123")
        XCTAssertEqual(submission.betaReviewState, "IN_REVIEW")
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/v1/betaAppReviewSubmissions")
        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"relationships":{"build":{"data":{"id":"build-123","type":"builds"}}},"type":"betaAppReviewSubmissions"}}"#
        )
    }

    func testFetchAppStoreVersionsMapsVersionStateAndReleaseType() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":[{"id":"version-123","type":"appStoreVersions","attributes":{"versionString":"1.2.6","appStoreState":"PREPARE_FOR_SUBMISSION","releaseType":"MANUAL"}}]}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let versions = try await client.fetchAppStoreVersions(appID: "app-123")

        XCTAssertEqual(versions, [
            ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")
        ])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/v1/apps/app-123/appStoreVersions")
    }

    func testUpdateAppStoreVersionBuildPatchesSelectedBuildRelationship() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 204, body: "")
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        try await client.updateAppStoreVersionBuild(appStoreVersionID: "version-123", buildID: "build-456")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(request.path, "/v1/appStoreVersions/version-123/relationships/build")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"id":"build-456","type":"builds"}}"#
        )
    }

    func testFetchAppStoreVersionLocalizationsMapsWhatsNew() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":[{"id":"loc-zh","type":"appStoreVersionLocalizations","attributes":{"locale":"zh-Hans","whatsNew":"修复问题","description":"介绍","keywords":"工具","promotionalText":"推荐"}}]}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let localizations = try await client.fetchAppStoreVersionLocalizations(appStoreVersionID: "version-123")

        XCTAssertEqual(localizations, [
            ASCAppStoreVersionLocalization(
                id: "loc-zh",
                locale: "zh-Hans",
                description: "介绍",
                keywords: "工具",
                marketingURL: nil,
                promotionalText: "推荐",
                supportURL: nil,
                whatsNew: "修复问题"
            )
        ])
        XCTAssertEqual(transport.requests.first?.path, "/v1/appStoreVersions/version-123/appStoreVersionLocalizations")
    }

    func testUpdateAppStoreVersionLocalizationPatchesEditableMetadata() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":{"id":"loc-zh","type":"appStoreVersionLocalizations","attributes":{"locale":"zh-Hans","whatsNew":"更新内容","description":"描述","keywords":"关键词","promotionalText":"宣传","supportUrl":"https://example.com/support","marketingUrl":"https://example.com"}}}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let localization = try await client.updateAppStoreVersionLocalization(
            localizationID: "loc-zh",
            update: ASCAppStoreVersionLocalizationUpdate(
                description: "描述",
                keywords: "关键词",
                marketingURL: "https://example.com",
                promotionalText: "宣传",
                supportURL: "https://example.com/support",
                whatsNew: "更新内容"
            )
        )

        XCTAssertEqual(localization.whatsNew, "更新内容")
        XCTAssertEqual(localization.supportURL, "https://example.com/support")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(request.path, "/v1/appStoreVersionLocalizations/loc-zh")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"attributes":{"description":"描述","keywords":"关键词","marketingUrl":"https:\/\/example.com","promotionalText":"宣传","supportUrl":"https:\/\/example.com\/support","whatsNew":"更新内容"},"id":"loc-zh","type":"appStoreVersionLocalizations"}}"#
        )
    }

    func testUpdateAppStoreReviewDetailPatchesContactAndDemoLogin() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":{"id":"review-detail-1","type":"appStoreReviewDetails","attributes":{"contactFirstName":"ye","contactLastName":"zhina","contactPhone":"+861777","contactEmail":"mdc@example.com","demoAccountRequired":true,"demoAccountName":"13662388632","demoAccountPassword":"123456","notes":"备注"}}}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let detail = try await client.updateAppStoreReviewDetail(
            reviewDetailID: "review-detail-1",
            update: ASCAppStoreReviewDetailUpdate(
                contactFirstName: "ye",
                contactLastName: "zhina",
                contactPhone: "+861777",
                contactEmail: "mdc@example.com",
                demoAccountName: "13662388632",
                demoAccountPassword: "123456",
                demoAccountRequired: true,
                notes: "备注"
            )
        )

        XCTAssertEqual(detail.demoAccountName, "13662388632")
        XCTAssertEqual(detail.demoAccountPassword, "123456")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(request.path, "/v1/appStoreReviewDetails/review-detail-1")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"attributes":{"contactEmail":"mdc@example.com","contactFirstName":"ye","contactLastName":"zhina","contactPhone":"+861777","demoAccountName":"13662388632","demoAccountPassword":"123456","demoAccountRequired":true,"notes":"备注"},"id":"review-detail-1","type":"appStoreReviewDetails"}}"#
        )
    }

    func testFetchAppScreenshotSetsMapsDisplayType() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":[{"id":"set-iphone-65","type":"appScreenshotSets","attributes":{"screenshotDisplayType":"APP_IPHONE_65"}},{"id":"set-ipad","type":"appScreenshotSets","attributes":{"screenshotDisplayType":"APP_IPAD_PRO_129"}}]}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let sets = try await client.fetchAppScreenshotSets(appStoreVersionLocalizationID: "loc-zh")

        XCTAssertEqual(sets, [
            ASCAppScreenshotSet(id: "set-iphone-65", screenshotDisplayType: "APP_IPHONE_65"),
            ASCAppScreenshotSet(id: "set-ipad", screenshotDisplayType: "APP_IPAD_PRO_129")
        ])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/v1/appStoreVersionLocalizations/loc-zh/appScreenshotSets")
        XCTAssertEqual(request.queryItems["limit"], "200")
    }

    func testFetchAppScreenshotsMapsFileAndImageAsset() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(
                statusCode: 200,
                body: #"{"data":[{"id":"shot-1","type":"appScreenshots","attributes":{"fileName":"screen1.png","fileSize":12345,"imageAsset":{"templateUrl":"https://is1-ssl.mzstatic.com/image/thumb/{w}x{h}.png","width":1242,"height":2688},"assetDeliveryState":{"state":"COMPLETE"}}},{"id":"shot-2","type":"appScreenshots","attributes":{"fileName":"screen2.png","fileSize":67890,"imageAsset":{"templateUrl":"https://is1-ssl.mzstatic.com/image/thumb/{w}x{h}bb.png","width":1242,"height":2688},"assetDeliveryState":{"state":"COMPLETE"}}}]}"#
            )
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let screenshots = try await client.fetchAppScreenshots(appScreenshotSetID: "set-iphone-65")

        XCTAssertEqual(screenshots, [
            ASCAppScreenshot(
                id: "shot-1",
                fileName: "screen1.png",
                fileSize: 12345,
                imageURLTemplate: "https://is1-ssl.mzstatic.com/image/thumb/{w}x{h}.png",
                width: 1242,
                height: 2688,
                assetDeliveryState: "COMPLETE"
            ),
            ASCAppScreenshot(
                id: "shot-2",
                fileName: "screen2.png",
                fileSize: 67890,
                imageURLTemplate: "https://is1-ssl.mzstatic.com/image/thumb/{w}x{h}bb.png",
                width: 1242,
                height: 2688,
                assetDeliveryState: "COMPLETE"
            )
        ])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/v1/appScreenshotSets/set-iphone-65/appScreenshots")
        XCTAssertEqual(request.queryItems["limit"], "200")
    }

    func testDefaultTransportUsesBoundedRequestTimeout() {
        // A stalled App Store Connect call must fail fast instead of hanging the UI forever.
        let transport = URLSessionASCTransport()
        XCTAssertEqual(transport.session.configuration.timeoutIntervalForRequest, URLSessionASCTransport.defaultRequestTimeout)
        XCTAssertFalse(transport.session.configuration.waitsForConnectivity)
    }

    func testSubmitReviewSubmissionMarksSubmissionSubmitted() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":{"id":"review-123","type":"reviewSubmissions","attributes":{"state":"WAITING_FOR_REVIEW"}}}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let submission = try await client.submitReviewSubmission(reviewSubmissionID: "review-123")

        XCTAssertEqual(submission, ASCReviewSubmission(id: "review-123", state: "WAITING_FOR_REVIEW"))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(request.path, "/v1/reviewSubmissions/review-123")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"attributes":{"submitted":true},"id":"review-123","type":"reviewSubmissions"}}"#
        )
    }

    func testFetchActiveReviewSubmissionReturnsNonCompleteSubmission() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":[{"id":"rs-done","type":"reviewSubmissions","attributes":{"state":"COMPLETE"}},{"id":"rs-active","type":"reviewSubmissions","attributes":{"state":"WAITING_FOR_REVIEW"}}]}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let submission = try await client.fetchActiveReviewSubmission(appID: "app-123")

        XCTAssertEqual(submission, ASCReviewSubmission(id: "rs-active", state: "WAITING_FOR_REVIEW"))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/v1/reviewSubmissions")
        XCTAssertEqual(request.queryItems["filter[app]"], "app-123")
        XCTAssertEqual(request.queryItems["filter[platform]"], "IOS")
    }

    func testCancelReviewSubmissionSendsCanceledTrue() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":{"id":"rs-active","type":"reviewSubmissions","attributes":{"state":"CANCELING"}}}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let submission = try await client.cancelReviewSubmission(reviewSubmissionID: "rs-active")

        XCTAssertEqual(submission, ASCReviewSubmission(id: "rs-active", state: "CANCELING"))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(request.path, "/v1/reviewSubmissions/rs-active")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"attributes":{"canceled":true},"id":"rs-active","type":"reviewSubmissions"}}"#
        )
    }

    func testUpdateReleaseTypePatchesVersion() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 200, body: #"{"data":{"id":"version-123","type":"appStoreVersions","attributes":{"versionString":"1.2.6","appStoreState":"PREPARE_FOR_SUBMISSION","releaseType":"AFTER_APPROVAL"}}}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        let version = try await client.updateAppStoreVersionReleaseType(appStoreVersionID: "version-123", releaseType: "AFTER_APPROVAL")

        XCTAssertEqual(version.releaseType, "AFTER_APPROVAL")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "PATCH")
        XCTAssertEqual(request.path, "/v1/appStoreVersions/version-123")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"attributes":{"releaseType":"AFTER_APPROVAL"},"id":"version-123","type":"appStoreVersions"}}"#
        )
    }

    func testRequestReleasePostsReleaseRequest() async throws {
        let transport = StubASCTransport(responses: [
            ASCTransportResponse(statusCode: 201, body: #"{"data":{"id":"release-1","type":"appStoreVersionReleaseRequests"}}"#)
        ])
        let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

        try await client.requestAppStoreVersionRelease(appStoreVersionID: "version-123")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/v1/appStoreVersionReleaseRequests")
        XCTAssertEqual(
            String(data: try XCTUnwrap(request.body), encoding: .utf8),
            #"{"data":{"relationships":{"appStoreVersion":{"data":{"id":"version-123","type":"appStoreVersions"}}},"type":"appStoreVersionReleaseRequests"}}"#
        )
    }
}
