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
}
