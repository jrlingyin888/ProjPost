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

public struct ASCAppStoreVersion: Equatable {
    public var id: String
    public var versionString: String
    public var state: String?
    public var releaseType: String?

    public init(id: String, versionString: String, state: String?, releaseType: String?) {
        self.id = id
        self.versionString = versionString
        self.state = state
        self.releaseType = releaseType
    }
}

public struct ASCAppStoreReviewDetail: Equatable {
    public var id: String
    public var contactFirstName: String?
    public var contactLastName: String?
    public var contactPhone: String?
    public var contactEmail: String?
    public var demoAccountName: String?
    public var demoAccountPassword: String?
    public var demoAccountRequired: Bool?
    public var notes: String?

    public init(
        id: String,
        contactFirstName: String?,
        contactLastName: String?,
        contactPhone: String?,
        contactEmail: String?,
        demoAccountName: String?,
        demoAccountPassword: String?,
        demoAccountRequired: Bool?,
        notes: String?
    ) {
        self.id = id
        self.contactFirstName = contactFirstName
        self.contactLastName = contactLastName
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.demoAccountName = demoAccountName
        self.demoAccountPassword = demoAccountPassword
        self.demoAccountRequired = demoAccountRequired
        self.notes = notes
    }
}

public struct ASCAppStoreVersionLocalization: Equatable {
    public var id: String
    public var locale: String
    public var description: String?
    public var keywords: String?
    public var marketingURL: String?
    public var promotionalText: String?
    public var supportURL: String?
    public var whatsNew: String?

    public init(
        id: String,
        locale: String,
        description: String?,
        keywords: String?,
        marketingURL: String?,
        promotionalText: String?,
        supportURL: String?,
        whatsNew: String?
    ) {
        self.id = id
        self.locale = locale
        self.description = description
        self.keywords = keywords
        self.marketingURL = marketingURL
        self.promotionalText = promotionalText
        self.supportURL = supportURL
        self.whatsNew = whatsNew
    }
}

public struct ASCAppStoreVersionLocalizationUpdate: Equatable {
    public var description: String?
    public var keywords: String?
    public var marketingURL: String?
    public var promotionalText: String?
    public var supportURL: String?
    public var whatsNew: String?

    public init(
        description: String?,
        keywords: String?,
        marketingURL: String?,
        promotionalText: String?,
        supportURL: String?,
        whatsNew: String?
    ) {
        self.description = description
        self.keywords = keywords
        self.marketingURL = marketingURL
        self.promotionalText = promotionalText
        self.supportURL = supportURL
        self.whatsNew = whatsNew
    }
}

public struct ASCAppStoreReviewDetailUpdate: Equatable {
    public var contactFirstName: String?
    public var contactLastName: String?
    public var contactPhone: String?
    public var contactEmail: String?
    public var demoAccountName: String?
    public var demoAccountPassword: String?
    public var demoAccountRequired: Bool?
    public var notes: String?

    public init(
        contactFirstName: String?,
        contactLastName: String?,
        contactPhone: String?,
        contactEmail: String?,
        demoAccountName: String?,
        demoAccountPassword: String?,
        demoAccountRequired: Bool?,
        notes: String?
    ) {
        self.contactFirstName = contactFirstName
        self.contactLastName = contactLastName
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.demoAccountName = demoAccountName
        self.demoAccountPassword = demoAccountPassword
        self.demoAccountRequired = demoAccountRequired
        self.notes = notes
    }
}

public struct ASCAppScreenshotSet: Equatable {
    public var id: String
    public var screenshotDisplayType: String

    public init(id: String, screenshotDisplayType: String) {
        self.id = id
        self.screenshotDisplayType = screenshotDisplayType
    }
}

public struct ASCAppScreenshot: Equatable {
    public var id: String
    public var fileName: String?
    public var fileSize: Int?
    public var imageURLTemplate: String?
    public var width: Int?
    public var height: Int?
    public var assetDeliveryState: String?

    public init(
        id: String,
        fileName: String?,
        fileSize: Int?,
        imageURLTemplate: String?,
        width: Int?,
        height: Int?,
        assetDeliveryState: String?
    ) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.imageURLTemplate = imageURLTemplate
        self.width = width
        self.height = height
        self.assetDeliveryState = assetDeliveryState
    }
}

public struct ASCReviewSubmission: Equatable {
    public var id: String
    public var state: String?

    public init(id: String, state: String?) {
        self.id = id
        self.state = state
    }
}

public struct ASCReviewSubmissionItem: Equatable {
    public var id: String
    public var state: String?

    public init(id: String, state: String?) {
        self.id = id
        self.state = state
    }
}

public protocol AppStoreConnectClientProtocol {
    func fetchApp(bundleID: String) async throws -> ASCApp?
    func fetchBundleID(identifier: String) async throws -> ASCBundleID?
    func fetchBuilds(appID: String, appVersion: String?, buildNumber: String?) async throws -> [ASCBuild]
    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup]
    func fetchBuildsForBetaGroup(betaGroupID: String) async throws -> [ASCBuild]
    func fetchBetaReviewSubmission(buildID: String) async throws -> ASCBetaReviewSubmission?
    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws
    func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup
    func submitBetaReview(buildID: String) async throws -> ASCBetaReviewSubmission
    func fetchAppStoreVersions(appID: String) async throws -> [ASCAppStoreVersion]
    func createAppStoreVersion(appID: String, versionString: String, releaseType: String?) async throws -> ASCAppStoreVersion
    func fetchAppStoreVersionBuildID(appStoreVersionID: String) async throws -> String?
    func updateAppStoreVersionBuild(appStoreVersionID: String, buildID: String) async throws
    func fetchAppStoreReviewDetail(appStoreVersionID: String) async throws -> ASCAppStoreReviewDetail?
    func fetchAppStoreVersionLocalizations(appStoreVersionID: String) async throws -> [ASCAppStoreVersionLocalization]
    func updateAppStoreVersionLocalization(localizationID: String, update: ASCAppStoreVersionLocalizationUpdate) async throws -> ASCAppStoreVersionLocalization
    func updateAppStoreReviewDetail(reviewDetailID: String, update: ASCAppStoreReviewDetailUpdate) async throws -> ASCAppStoreReviewDetail
    func fetchAppScreenshotSets(appStoreVersionLocalizationID: String) async throws -> [ASCAppScreenshotSet]
    func fetchAppScreenshots(appScreenshotSetID: String) async throws -> [ASCAppScreenshot]
    func createReviewSubmission(appID: String) async throws -> ASCReviewSubmission
    func createReviewSubmissionItem(reviewSubmissionID: String, appStoreVersionID: String) async throws -> ASCReviewSubmissionItem
    func submitReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission
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

    public func fetchBetaReviewSubmission(buildID: String) async throws -> ASCBetaReviewSubmission? {
        do {
            let json = try await get(path: "/v1/builds/\(buildID)/betaAppReviewSubmission", query: [:])
            guard let data = json["data"] as? [String: Any] else {
                throw AppStoreConnectError.malformedResponse
            }
            return Self.mapBetaReviewSubmission(data)
        } catch let error as AppStoreConnectError {
            if case .badStatus(404, _) = error {
                return nil
            }
            throw error
        }
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

    public func fetchAppStoreVersions(appID: String) async throws -> [ASCAppStoreVersion] {
        let json = try await get(path: "/v1/apps/\(appID)/appStoreVersions", query: [:])
        return try dataArray(from: json).map(Self.mapAppStoreVersion)
    }

    public func createAppStoreVersion(appID: String, versionString: String, releaseType: String? = "MANUAL") async throws -> ASCAppStoreVersion {
        var attributes: [String: Any] = [
            "platform": "IOS",
            "versionString": versionString
        ]
        if let releaseType {
            attributes["releaseType"] = releaseType
        }
        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "attributes": attributes,
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": appID
                        ]
                    ]
                ]
            ]
        ]
        let json = try await send(method: "POST", path: "/v1/appStoreVersions", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapAppStoreVersion(data)
    }

    public func fetchAppStoreVersionBuildID(appStoreVersionID: String) async throws -> String? {
        do {
            let json = try await get(path: "/v1/appStoreVersions/\(appStoreVersionID)/relationships/build", query: [:])
            guard let data = json["data"] as? [String: Any] else { return nil }
            return data["id"] as? String
        } catch let error as AppStoreConnectError {
            if case .badStatus(404, _) = error {
                return nil
            }
            throw error
        }
    }

    public func updateAppStoreVersionBuild(appStoreVersionID: String, buildID: String) async throws {
        let body: [String: Any] = [
            "data": [
                "type": "builds",
                "id": buildID
            ]
        ]
        try await sendNoContent(
            method: "PATCH",
            path: "/v1/appStoreVersions/\(appStoreVersionID)/relationships/build",
            query: [:],
            jsonBody: body
        )
    }

    public func fetchAppStoreReviewDetail(appStoreVersionID: String) async throws -> ASCAppStoreReviewDetail? {
        do {
            let json = try await get(path: "/v1/appStoreVersions/\(appStoreVersionID)/appStoreReviewDetail", query: [:])
            guard let data = json["data"] as? [String: Any] else {
                throw AppStoreConnectError.malformedResponse
            }
            return Self.mapAppStoreReviewDetail(data)
        } catch let error as AppStoreConnectError {
            if case .badStatus(404, _) = error {
                return nil
            }
            throw error
        }
    }

    public func fetchAppStoreVersionLocalizations(appStoreVersionID: String) async throws -> [ASCAppStoreVersionLocalization] {
        let json = try await get(path: "/v1/appStoreVersions/\(appStoreVersionID)/appStoreVersionLocalizations", query: [:])
        return try dataArray(from: json).map(Self.mapAppStoreVersionLocalization)
    }

    public func updateAppStoreVersionLocalization(
        localizationID: String,
        update: ASCAppStoreVersionLocalizationUpdate
    ) async throws -> ASCAppStoreVersionLocalization {
        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "id": localizationID,
                "attributes": [
                    "description": Self.jsonValue(update.description),
                    "keywords": Self.jsonValue(update.keywords),
                    "marketingUrl": Self.jsonValue(update.marketingURL),
                    "promotionalText": Self.jsonValue(update.promotionalText),
                    "supportUrl": Self.jsonValue(update.supportURL),
                    "whatsNew": Self.jsonValue(update.whatsNew)
                ]
            ]
        ]
        let json = try await send(method: "PATCH", path: "/v1/appStoreVersionLocalizations/\(localizationID)", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapAppStoreVersionLocalization(data)
    }

    public func updateAppStoreReviewDetail(
        reviewDetailID: String,
        update: ASCAppStoreReviewDetailUpdate
    ) async throws -> ASCAppStoreReviewDetail {
        let body: [String: Any] = [
            "data": [
                "type": "appStoreReviewDetails",
                "id": reviewDetailID,
                "attributes": [
                    "contactFirstName": Self.jsonValue(update.contactFirstName),
                    "contactLastName": Self.jsonValue(update.contactLastName),
                    "contactPhone": Self.jsonValue(update.contactPhone),
                    "contactEmail": Self.jsonValue(update.contactEmail),
                    "demoAccountName": Self.jsonValue(update.demoAccountName),
                    "demoAccountPassword": Self.jsonValue(update.demoAccountPassword),
                    "demoAccountRequired": Self.jsonValue(update.demoAccountRequired),
                    "notes": Self.jsonValue(update.notes)
                ]
            ]
        ]
        let json = try await send(method: "PATCH", path: "/v1/appStoreReviewDetails/\(reviewDetailID)", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapAppStoreReviewDetail(data)
    }

    public func fetchAppScreenshotSets(appStoreVersionLocalizationID: String) async throws -> [ASCAppScreenshotSet] {
        let json = try await get(
            path: "/v1/appStoreVersionLocalizations/\(appStoreVersionLocalizationID)/appScreenshotSets",
            query: ["limit": "200"]
        )
        return try dataArray(from: json).map(Self.mapAppScreenshotSet)
    }

    public func fetchAppScreenshots(appScreenshotSetID: String) async throws -> [ASCAppScreenshot] {
        let json = try await get(
            path: "/v1/appScreenshotSets/\(appScreenshotSetID)/appScreenshots",
            query: ["limit": "200"]
        )
        return try dataArray(from: json).map(Self.mapAppScreenshot)
    }

    public func createReviewSubmission(appID: String) async throws -> ASCReviewSubmission {
        let body: [String: Any] = [
            "data": [
                "type": "reviewSubmissions",
                "attributes": [
                    "platform": "IOS"
                ],
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": appID
                        ]
                    ]
                ]
            ]
        ]
        let json = try await send(method: "POST", path: "/v1/reviewSubmissions", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapReviewSubmission(data)
    }

    public func createReviewSubmissionItem(reviewSubmissionID: String, appStoreVersionID: String) async throws -> ASCReviewSubmissionItem {
        let body: [String: Any] = [
            "data": [
                "type": "reviewSubmissionItems",
                "relationships": [
                    "reviewSubmission": [
                        "data": [
                            "type": "reviewSubmissions",
                            "id": reviewSubmissionID
                        ]
                    ],
                    "appStoreVersion": [
                        "data": [
                            "type": "appStoreVersions",
                            "id": appStoreVersionID
                        ]
                    ]
                ]
            ]
        ]
        let json = try await send(method: "POST", path: "/v1/reviewSubmissionItems", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapReviewSubmissionItem(data)
    }

    public func submitReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission {
        let body: [String: Any] = [
            "data": [
                "type": "reviewSubmissions",
                "id": reviewSubmissionID,
                "attributes": [
                    "submitted": true
                ]
            ]
        ]
        let json = try await send(method: "PATCH", path: "/v1/reviewSubmissions/\(reviewSubmissionID)", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapReviewSubmission(data)
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

    private static func mapAppStoreVersion(_ item: [String: Any]) -> ASCAppStoreVersion {
        let attributes = item["attributes"] as? [String: Any]
        return ASCAppStoreVersion(
            id: item["id"] as? String ?? "",
            versionString: attributes?["versionString"] as? String ?? "",
            state: (attributes?["appStoreState"] as? String) ?? (attributes?["state"] as? String),
            releaseType: attributes?["releaseType"] as? String
        )
    }

    private static func mapAppStoreReviewDetail(_ item: [String: Any]) -> ASCAppStoreReviewDetail {
        let attributes = item["attributes"] as? [String: Any]
        return ASCAppStoreReviewDetail(
            id: item["id"] as? String ?? "",
            contactFirstName: attributes?["contactFirstName"] as? String,
            contactLastName: attributes?["contactLastName"] as? String,
            contactPhone: attributes?["contactPhone"] as? String,
            contactEmail: attributes?["contactEmail"] as? String,
            demoAccountName: attributes?["demoAccountName"] as? String,
            demoAccountPassword: attributes?["demoAccountPassword"] as? String,
            demoAccountRequired: attributes?["demoAccountRequired"] as? Bool,
            notes: attributes?["notes"] as? String
        )
    }

    private static func mapAppStoreVersionLocalization(_ item: [String: Any]) -> ASCAppStoreVersionLocalization {
        let attributes = item["attributes"] as? [String: Any]
        return ASCAppStoreVersionLocalization(
            id: item["id"] as? String ?? "",
            locale: attributes?["locale"] as? String ?? "",
            description: attributes?["description"] as? String,
            keywords: attributes?["keywords"] as? String,
            marketingURL: attributes?["marketingUrl"] as? String,
            promotionalText: attributes?["promotionalText"] as? String,
            supportURL: attributes?["supportUrl"] as? String,
            whatsNew: attributes?["whatsNew"] as? String
        )
    }

    private static func mapAppScreenshotSet(_ item: [String: Any]) -> ASCAppScreenshotSet {
        let attributes = item["attributes"] as? [String: Any]
        return ASCAppScreenshotSet(
            id: item["id"] as? String ?? "",
            screenshotDisplayType: attributes?["screenshotDisplayType"] as? String ?? ""
        )
    }

    private static func mapAppScreenshot(_ item: [String: Any]) -> ASCAppScreenshot {
        let attributes = item["attributes"] as? [String: Any]
        let imageAsset = attributes?["imageAsset"] as? [String: Any]
        let assetDeliveryState = attributes?["assetDeliveryState"] as? [String: Any]
        return ASCAppScreenshot(
            id: item["id"] as? String ?? "",
            fileName: attributes?["fileName"] as? String,
            fileSize: Self.intValue(attributes?["fileSize"]),
            imageURLTemplate: imageAsset?["templateUrl"] as? String,
            width: Self.intValue(imageAsset?["width"]),
            height: Self.intValue(imageAsset?["height"]),
            assetDeliveryState: assetDeliveryState?["state"] as? String
        )
    }

    private static func mapReviewSubmission(_ item: [String: Any]) -> ASCReviewSubmission {
        let attributes = item["attributes"] as? [String: Any]
        return ASCReviewSubmission(
            id: item["id"] as? String ?? "",
            state: attributes?["state"] as? String
        )
    }

    private static func mapReviewSubmissionItem(_ item: [String: Any]) -> ASCReviewSubmissionItem {
        let attributes = item["attributes"] as? [String: Any]
        return ASCReviewSubmissionItem(
            id: item["id"] as? String ?? "",
            state: attributes?["state"] as? String
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

    private static func jsonValue(_ value: String?) -> Any {
        value ?? NSNull()
    }

    private static func jsonValue(_ value: Bool?) -> Any {
        value ?? NSNull()
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
