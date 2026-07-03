import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ASCApp: Equatable {
    public var id: String
    public var name: String
    public var bundleID: String

    public init(id: String, name: String, bundleID: String) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
    }
}

public struct ASCBundleID: Equatable {
    public var id: String
    public var identifier: String
    public var platform: String?

    public init(id: String, identifier: String, platform: String?) {
        self.id = id
        self.identifier = identifier
        self.platform = platform
    }
}

public struct ASCBuild: Equatable {
    public var id: String
    public var version: String
    public var processingState: String?
    public var betaReviewState: String?

    public init(id: String, version: String, processingState: String?, betaReviewState: String? = nil) {
        self.id = id
        self.version = version
        self.processingState = processingState
        self.betaReviewState = betaReviewState
    }
}

public struct ASCBetaGroup: Equatable {
    public var id: String
    public var name: String
    public var isInternalGroup: Bool
    public var publicLinkEnabled: Bool
    public var publicLink: String?
    public var publicLinkLimit: Int?

    public init(
        id: String,
        name: String,
        isInternalGroup: Bool,
        publicLinkEnabled: Bool,
        publicLink: String?,
        publicLinkLimit: Int?
    ) {
        self.id = id
        self.name = name
        self.isInternalGroup = isInternalGroup
        self.publicLinkEnabled = publicLinkEnabled
        self.publicLink = publicLink
        self.publicLinkLimit = publicLinkLimit
    }
}

public struct ASCBetaReviewSubmission: Equatable {
    public var id: String
    public var betaReviewState: String?

    public init(id: String, betaReviewState: String?) {
        self.id = id
        self.betaReviewState = betaReviewState
    }
}

public protocol AppStoreConnectClientProtocol {
    func fetchApp(bundleID: String) async throws -> ASCApp?
    func fetchBundleID(identifier: String) async throws -> ASCBundleID?
    func fetchBuilds(appID: String, appVersion: String?, buildNumber: String?) async throws -> [ASCBuild]
    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup]
    func fetchBuildsForBetaGroup(betaGroupID: String) async throws -> [ASCBuild]
    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws
    func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup
    func submitBetaReview(buildID: String) async throws -> ASCBetaReviewSubmission
}

public struct ASCRequest: Equatable {
    public var method: String
    public var path: String
    public var queryItems: [String: String]
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, path: String, queryItems: [String: String], headers: [String: String], body: Data?) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
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
        return try dataArray(from: json).first.map(Self.mapApp)
    }

    public func fetchBundleID(identifier: String) async throws -> ASCBundleID? {
        let json = try await get(
            path: "/v1/bundleIds",
            query: ["filter[identifier]": identifier, "filter[platform]": "IOS"]
        )
        return try dataArray(from: json).first.map(Self.mapBundleID)
    }

    public func fetchBuilds(appID: String, appVersion: String?, buildNumber: String?) async throws -> [ASCBuild] {
        var query = ["filter[app]": appID]
        if let appVersion, !appVersion.isEmpty {
            query["filter[preReleaseVersion.version]"] = appVersion
        }
        if let buildNumber {
            query["filter[version]"] = buildNumber
        }
        let json = try await get(path: "/v1/builds", query: query)
        return try dataArray(from: json).map(Self.mapBuild)
    }

    public func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup] {
        let json = try await get(path: "/v1/betaGroups", query: ["filter[app]": appID])
        return try dataArray(from: json).map(Self.mapBetaGroup)
    }

    public func fetchBuildsForBetaGroup(betaGroupID: String) async throws -> [ASCBuild] {
        let json = try await get(path: "/v1/betaGroups/\(betaGroupID)/builds", query: [:])
        return try dataArray(from: json).map(Self.mapBuild)
    }

    public func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {
        let body: [String: Any] = [
            "data": [
                ["type": "builds", "id": buildID]
            ]
        ]
        try await sendNoContent(
            method: "POST",
            path: "/v1/betaGroups/\(betaGroupID)/relationships/builds",
            query: [:],
            jsonBody: body
        )
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
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapBetaGroup(data)
    }

    public func submitBetaReview(buildID: String) async throws -> ASCBetaReviewSubmission {
        let body: [String: Any] = [
            "data": [
                "type": "betaAppReviewSubmissions",
                "relationships": [
                    "build": [
                        "data": [
                            "type": "builds",
                            "id": buildID
                        ]
                    ]
                ]
            ]
        ]
        let json = try await send(method: "POST", path: "/v1/betaAppReviewSubmissions", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapBetaReviewSubmission(data)
    }

    private func get(path: String, query: [String: String]) async throws -> [String: Any] {
        try await send(method: "GET", path: path, query: query, jsonBody: nil)
    }

    private func sendNoContent(method: String, path: String, query: [String: String], jsonBody: Any?) async throws {
        let token = try jwtProvider()
        var headers = ["Authorization": "Bearer \(token)"]
        var bodyData: Data?
        if let jsonBody {
            headers["Content-Type"] = "application/json"
            bodyData = try JSONSerialization.data(withJSONObject: jsonBody, options: [.sortedKeys])
        }

        let request = ASCRequest(method: method, path: path, queryItems: query, headers: headers, body: bodyData)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw AppStoreConnectError.badStatus(response.statusCode, response.body)
        }
    }

    private func send(method: String, path: String, query: [String: String], jsonBody: Any?) async throws -> [String: Any] {
        let token = try jwtProvider()
        var headers = ["Authorization": "Bearer \(token)"]
        var bodyData: Data?
        if let jsonBody {
            headers["Content-Type"] = "application/json"
            bodyData = try JSONSerialization.data(withJSONObject: jsonBody, options: [.sortedKeys])
        }

        let request = ASCRequest(method: method, path: path, queryItems: query, headers: headers, body: bodyData)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw AppStoreConnectError.badStatus(response.statusCode, response.body)
        }

        let data = Data(response.body.utf8)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let object = json as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return object
    }

    private func dataArray(from json: [String: Any]) throws -> [[String: Any]] {
        guard let data = json["data"] as? [[String: Any]] else {
            throw AppStoreConnectError.malformedResponse
        }
        return data
    }

    private static func mapApp(_ item: [String: Any]) -> ASCApp {
        let attributes = item["attributes"] as? [String: Any]
        return ASCApp(
            id: item["id"] as? String ?? "",
            name: attributes?["name"] as? String ?? "",
            bundleID: attributes?["bundleId"] as? String ?? ""
        )
    }

    private static func mapBundleID(_ item: [String: Any]) -> ASCBundleID {
        let attributes = item["attributes"] as? [String: Any]
        return ASCBundleID(
            id: item["id"] as? String ?? "",
            identifier: attributes?["identifier"] as? String ?? "",
            platform: attributes?["platform"] as? String
        )
    }

    private static func mapBuild(_ item: [String: Any]) -> ASCBuild {
        let attributes = item["attributes"] as? [String: Any]
        return ASCBuild(
            id: item["id"] as? String ?? "",
            version: attributes?["version"] as? String ?? "",
            processingState: attributes?["processingState"] as? String,
            betaReviewState: attributes?["betaReviewState"] as? String
        )
    }

    private static func mapBetaGroup(_ item: [String: Any]) -> ASCBetaGroup {
        let attributes = item["attributes"] as? [String: Any]
        return ASCBetaGroup(
            id: item["id"] as? String ?? "",
            name: attributes?["name"] as? String ?? "",
            isInternalGroup: attributes?["isInternalGroup"] as? Bool ?? false,
            publicLinkEnabled: attributes?["publicLinkEnabled"] as? Bool ?? false,
            publicLink: attributes?["publicLink"] as? String,
            publicLinkLimit: Self.intValue(attributes?["publicLinkLimit"])
        )
    }

    private static func mapBetaReviewSubmission(_ item: [String: Any]) -> ASCBetaReviewSubmission {
        let attributes = item["attributes"] as? [String: Any]
        return ASCBetaReviewSubmission(
            id: item["id"] as? String ?? "",
            betaReviewState: attributes?["betaReviewState"] as? String
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }
}

public final class URLSessionASCTransport: ASCTransport {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: ASCRequest) async throws -> ASCTransportResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = request.path
        components.queryItems = request.queryItems
            .map { URLQueryItem(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = request.method
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
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
