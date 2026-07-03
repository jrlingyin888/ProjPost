import Foundation

public struct ProjectAppliedSettings: Codable, Equatable {
    public var bundleID: String?
    public var version: String?
    public var buildNumber: String?

    public init(bundleID: String?, version: String?, buildNumber: String?) {
        self.bundleID = bundleID
        self.version = version
        self.buildNumber = buildNumber
    }
}

public struct ProjectProfile: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var projectPath: String
    public var workspacePath: String?
    public var projectFilePath: String?
    public var scheme: String?
    public var configuration: String
    public var bundleID: String?
    public var version: String?
    public var buildNumber: String?
    public var teamID: String?
    public var selectedAccountID: UUID?
    public var lastUpload: UploadSummary?
    public var appliedSettings: ProjectAppliedSettings?
    public var autoLinkExternalGroupsAfterBetaApproval: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        projectPath: String,
        workspacePath: String?,
        projectFilePath: String?,
        scheme: String?,
        configuration: String = "Release",
        bundleID: String?,
        version: String?,
        buildNumber: String?,
        teamID: String?,
        selectedAccountID: UUID?,
        lastUpload: UploadSummary?,
        appliedSettings: ProjectAppliedSettings? = nil,
        autoLinkExternalGroupsAfterBetaApproval: Bool = true
    ) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.workspacePath = workspacePath
        self.projectFilePath = projectFilePath
        self.scheme = scheme
        self.configuration = configuration
        self.bundleID = bundleID
        self.version = version
        self.buildNumber = buildNumber
        self.teamID = teamID
        self.selectedAccountID = selectedAccountID
        self.lastUpload = lastUpload
        self.appliedSettings = appliedSettings ?? ProjectAppliedSettings(
            bundleID: bundleID,
            version: version,
            buildNumber: buildNumber
        )
        self.autoLinkExternalGroupsAfterBetaApproval = autoLinkExternalGroupsAfterBetaApproval
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case projectPath
        case workspacePath
        case projectFilePath
        case scheme
        case configuration
        case bundleID
        case version
        case buildNumber
        case teamID
        case selectedAccountID
        case lastUpload
        case appliedSettings
        case autoLinkExternalGroupsAfterBetaApproval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        projectPath = try container.decode(String.self, forKey: .projectPath)
        workspacePath = try container.decodeIfPresent(String.self, forKey: .workspacePath)
        projectFilePath = try container.decodeIfPresent(String.self, forKey: .projectFilePath)
        scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
        configuration = try container.decode(String.self, forKey: .configuration)
        bundleID = try container.decodeIfPresent(String.self, forKey: .bundleID)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        buildNumber = try container.decodeIfPresent(String.self, forKey: .buildNumber)
        teamID = try container.decodeIfPresent(String.self, forKey: .teamID)
        selectedAccountID = try container.decodeIfPresent(UUID.self, forKey: .selectedAccountID)
        lastUpload = try container.decodeIfPresent(UploadSummary.self, forKey: .lastUpload)
        appliedSettings = try container.decodeIfPresent(ProjectAppliedSettings.self, forKey: .appliedSettings) ?? ProjectAppliedSettings(
            bundleID: bundleID,
            version: version,
            buildNumber: buildNumber
        )
        autoLinkExternalGroupsAfterBetaApproval = try container.decodeIfPresent(Bool.self, forKey: .autoLinkExternalGroupsAfterBetaApproval) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(projectPath, forKey: .projectPath)
        try container.encodeIfPresent(workspacePath, forKey: .workspacePath)
        try container.encodeIfPresent(projectFilePath, forKey: .projectFilePath)
        try container.encodeIfPresent(scheme, forKey: .scheme)
        try container.encode(configuration, forKey: .configuration)
        try container.encodeIfPresent(bundleID, forKey: .bundleID)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(buildNumber, forKey: .buildNumber)
        try container.encodeIfPresent(teamID, forKey: .teamID)
        try container.encodeIfPresent(selectedAccountID, forKey: .selectedAccountID)
        try container.encodeIfPresent(lastUpload, forKey: .lastUpload)
        try container.encodeIfPresent(appliedSettings, forKey: .appliedSettings)
        try container.encode(autoLinkExternalGroupsAfterBetaApproval, forKey: .autoLinkExternalGroupsAfterBetaApproval)
    }

    public var versionDisplay: String {
        let versionText = version ?? "-"
        let buildText = buildNumber ?? "-"
        return "v\(versionText) (\(buildText))"
    }

    public var statusLabel: String {
        guard let lastUpload else { return "未配置" }
        return lastUpload.succeeded ? "最近上传成功" : "最近上传失败"
    }
}

public struct UploadSummary: Codable, Equatable {
    public var version: String
    public var buildNumber: String
    public var uploadedAt: Date
    public var succeeded: Bool
    public var message: String

    public init(version: String, buildNumber: String, uploadedAt: Date, succeeded: Bool, message: String) {
        self.version = version
        self.buildNumber = buildNumber
        self.uploadedAt = uploadedAt
        self.succeeded = succeeded
        self.message = message
    }
}

public struct AppleAccountProfile: Codable, Equatable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var keyID: String
    public var issuerID: String
    public var teamID: String?
    public var lastVerifiedAt: Date?

    public init(id: UUID = UUID(), displayName: String, keyID: String, issuerID: String, teamID: String?, lastVerifiedAt: Date?) {
        self.id = id
        self.displayName = displayName
        self.keyID = keyID
        self.issuerID = issuerID
        self.teamID = teamID
        self.lastVerifiedAt = lastVerifiedAt
    }
}

public enum CheckSeverity: String, Codable, Equatable {
    case green
    case yellow
    case red
}

public struct CheckResult: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var message: String
    public var severity: CheckSeverity

    public init(id: String, title: String, message: String, severity: CheckSeverity) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
    }
}

public extension Array where Element == CheckResult {
    var blocksUpload: Bool {
        contains { $0.severity == .red }
    }
}

public enum UploadStep: String, Codable, CaseIterable, Equatable {
    case readProject
    case validateAccount
    case checkBundleAndApp
    case backupProjectFiles
    case applyProjectChanges
    case archive
    case exportIPA
    case validateIPA
    case upload
    case waitForAppleProcessing
    case assignTestFlightGroups
    case fetchPublicLink
}

public enum UploadJobState: Equatable {
    case idle
    case running(step: UploadStep)
    case succeeded(message: String)
    case failed(message: String)
    case cancelled
}

public enum BetaReviewSubmissionState: Equatable {
    case idle
    case running
    case succeeded(message: String)
    case failed(message: String)
}

public enum TestFlightDistributionGroupOperationState: Codable, Equatable {
    case idle
    case linked
    case failed(message: String)
}

public struct TestFlightDistributionGroup: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var isInternalGroup: Bool
    public var isCurrentBuildAssociated: Bool
    public var publicLinkEnabled: Bool
    public var publicLink: String?
    public var publicLinkLimit: Int?
    public var operationState: TestFlightDistributionGroupOperationState

    public init(
        id: String,
        name: String,
        isInternalGroup: Bool,
        isCurrentBuildAssociated: Bool,
        publicLinkEnabled: Bool,
        publicLink: String?,
        publicLinkLimit: Int?,
        operationState: TestFlightDistributionGroupOperationState = .idle
    ) {
        self.id = id
        self.name = name
        self.isInternalGroup = isInternalGroup
        self.isCurrentBuildAssociated = isCurrentBuildAssociated
        self.publicLinkEnabled = publicLinkEnabled
        self.publicLink = publicLink
        self.publicLinkLimit = publicLinkLimit
        self.operationState = operationState
    }
}

public struct TestFlightDistributionSnapshot: Codable, Equatable {
    public var appID: String
    public var buildID: String
    public var version: String
    public var buildNumber: String
    public var processingState: String?
    public var betaReviewState: String?
    public var betaReviewStateText: String
    public var internalGroups: [TestFlightDistributionGroup]
    public var externalGroups: [TestFlightDistributionGroup]

    public init(
        appID: String,
        buildID: String,
        version: String,
        buildNumber: String,
        processingState: String?,
        betaReviewState: String?,
        betaReviewStateText: String,
        internalGroups: [TestFlightDistributionGroup],
        externalGroups: [TestFlightDistributionGroup]
    ) {
        self.appID = appID
        self.buildID = buildID
        self.version = version
        self.buildNumber = buildNumber
        self.processingState = processingState
        self.betaReviewState = betaReviewState
        self.betaReviewStateText = betaReviewStateText
        self.internalGroups = internalGroups
        self.externalGroups = externalGroups
    }
}

public enum TestFlightDistributionState: Equatable {
    case idle
    case loading
    case loaded(TestFlightDistributionSnapshot)
    case linking(TestFlightDistributionSnapshot?)
    case failed(message: String)
}
