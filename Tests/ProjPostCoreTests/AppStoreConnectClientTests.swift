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
}
