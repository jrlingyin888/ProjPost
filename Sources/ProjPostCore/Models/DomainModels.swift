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
    public var autoLinkExternalGroupIDsAfterBetaApproval: Set<String>

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
        autoLinkExternalGroupsAfterBetaApproval: Bool = false,
        autoLinkExternalGroupIDsAfterBetaApproval: Set<String> = []
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
        self.autoLinkExternalGroupIDsAfterBetaApproval = autoLinkExternalGroupIDsAfterBetaApproval
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
        case autoLinkExternalGroupIDsAfterBetaApproval
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
        autoLinkExternalGroupsAfterBetaApproval = try container.decodeIfPresent(Bool.self, forKey: .autoLinkExternalGroupsAfterBetaApproval) ?? false
        autoLinkExternalGroupIDsAfterBetaApproval = try container.decodeIfPresent(Set<String>.self, forKey: .autoLinkExternalGroupIDsAfterBetaApproval) ?? []
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
        try container.encode(autoLinkExternalGroupIDsAfterBetaApproval, forKey: .autoLinkExternalGroupIDsAfterBetaApproval)
    }

    public var versionDisplay: String {
        let versionText = version ?? "-"
        let buildText = buildNumber ?? "-"
        return "v\(versionText) (\(buildText))"
    }

    public var statusLabel: String {
        statusLabel(language: .english)
    }

    public func statusLabel(language: AppLanguage) -> String {
        let strings = AppStrings(language: language)
        guard let lastUpload else { return strings.projectStatusNotConfigured }
        return lastUpload.succeeded ? strings.projectStatusLastUploadSucceeded : strings.projectStatusLastUploadFailed
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

public struct AppStoreReviewBuildOption: Equatable, Identifiable {
    public var id: String
    public var buildNumber: String
    public var processingState: String?
    public var isBound: Bool

    public init(id: String, buildNumber: String, processingState: String?, isBound: Bool) {
        self.id = id
        self.buildNumber = buildNumber
        self.processingState = processingState
        self.isBound = isBound
    }
}

public struct AppStoreReviewScreenshotSet: Equatable, Identifiable {
    public var id: String
    public var localizationID: String
    public var locale: String
    public var screenshotDisplayType: String
    public var screenshots: [ASCAppScreenshot]

    public init(
        id: String,
        localizationID: String,
        locale: String,
        screenshotDisplayType: String,
        screenshots: [ASCAppScreenshot]
    ) {
        self.id = id
        self.localizationID = localizationID
        self.locale = locale
        self.screenshotDisplayType = screenshotDisplayType
        self.screenshots = screenshots
    }
}

public struct AppStoreReviewLocalizationUpdate: Equatable {
    public var localizationID: String
    public var update: ASCAppStoreVersionLocalizationUpdate

    public init(localizationID: String, update: ASCAppStoreVersionLocalizationUpdate) {
        self.localizationID = localizationID
        self.update = update
    }
}

public struct AppStoreReviewAdvancedDraft: Equatable {
    public var reviewDetailID: String?
    public var reviewDetailUpdate: ASCAppStoreReviewDetailUpdate?
    public var localizationUpdates: [AppStoreReviewLocalizationUpdate]

    public init(
        reviewDetailID: String?,
        reviewDetailUpdate: ASCAppStoreReviewDetailUpdate?,
        localizationUpdates: [AppStoreReviewLocalizationUpdate]
    ) {
        self.reviewDetailID = reviewDetailID
        self.reviewDetailUpdate = reviewDetailUpdate
        self.localizationUpdates = localizationUpdates
    }
}

public struct AppStoreReviewSnapshot: Equatable {
    public var appID: String
    public var appStoreVersionID: String
    public var versionString: String
    public var versionState: String?
    public var releaseType: String?
    public var selectedBuildID: String?
    public var boundBuildID: String?
    public var builds: [AppStoreReviewBuildOption]
    public var reviewDetail: ASCAppStoreReviewDetail?
    public var localizations: [ASCAppStoreVersionLocalization]
    public var screenshotSets: [AppStoreReviewScreenshotSet]
    public var reviewSubmissionState: String?
    public var reviewSubmissionID: String?

    public init(
        appID: String,
        appStoreVersionID: String,
        versionString: String,
        versionState: String?,
        releaseType: String?,
        selectedBuildID: String?,
        boundBuildID: String?,
        builds: [AppStoreReviewBuildOption],
        reviewDetail: ASCAppStoreReviewDetail?,
        localizations: [ASCAppStoreVersionLocalization],
        screenshotSets: [AppStoreReviewScreenshotSet] = [],
        reviewSubmissionState: String?,
        reviewSubmissionID: String? = nil
    ) {
        self.appID = appID
        self.appStoreVersionID = appStoreVersionID
        self.versionString = versionString
        self.versionState = versionState
        self.releaseType = releaseType
        self.selectedBuildID = selectedBuildID
        self.boundBuildID = boundBuildID
        self.builds = builds
        self.reviewDetail = reviewDetail
        self.localizations = localizations
        self.screenshotSets = screenshotSets
        self.reviewSubmissionState = reviewSubmissionState
        self.reviewSubmissionID = reviewSubmissionID
    }
}

public enum AppStoreReviewState: Equatable {
    case idle
    case loading
    case preparing(AppStoreReviewSnapshot?)
    case binding(AppStoreReviewSnapshot?)
    case saving(AppStoreReviewSnapshot?)
    case submitting(AppStoreReviewSnapshot?)
    case loaded(AppStoreReviewSnapshot)
    case succeeded(message: String, snapshot: AppStoreReviewSnapshot?)
    case failed(message: String, snapshot: AppStoreReviewSnapshot?)
}

public enum AppStoreReviewPhase: Equatable {
    case noVersion
    case editable
    case inReview
    case canceling
    case pendingDeveloperRelease
    case releasing
    case live
    case replaced

    public init(versionState: String?, submissionState: String?) {
        switch submissionState {
        case "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES":
            self = .inReview
            return
        case "CANCELING":
            self = .canceling
            return
        default:
            break
        }
        switch versionState {
        case "WAITING_FOR_REVIEW", "IN_REVIEW":
            self = .inReview
        case "PENDING_DEVELOPER_RELEASE":
            self = .pendingDeveloperRelease
        case "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE", "PROCESSING_FOR_DISTRIBUTION":
            self = .releasing
        case "READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "ACCEPTED":
            self = .live
        case "REPLACED_WITH_NEW_VERSION":
            self = .replaced
        default:
            self = .editable
        }
    }

    public static func resolve(snapshot: AppStoreReviewSnapshot?) -> AppStoreReviewPhase {
        guard let snapshot else { return .noVersion }
        return AppStoreReviewPhase(versionState: snapshot.versionState, submissionState: snapshot.reviewSubmissionState)
    }
}

public enum ReviewReadinessSeverity: Equatable {
    case green
    case yellow
    case red
}

public enum ReviewReadinessKind: Equatable {
    case buildValid
    case whatsNewFilled
    case reviewContactComplete
    case screenshotsPresent
    case exportCompliance
}

public struct ReviewReadinessItem: Equatable, Identifiable {
    public var kind: ReviewReadinessKind
    public var severity: ReviewReadinessSeverity
    public var detail: String?

    public init(kind: ReviewReadinessKind, severity: ReviewReadinessSeverity, detail: String? = nil) {
        self.kind = kind
        self.severity = severity
        self.detail = detail
    }

    public var id: String { "\(kind)" }
}

public enum AppStoreReviewReadiness {
    public static func evaluate(snapshot: AppStoreReviewSnapshot) -> [ReviewReadinessItem] {
        [
            buildItem(snapshot),
            whatsNewItem(snapshot),
            contactItem(snapshot),
            screenshotItem(snapshot),
            exportComplianceItem(snapshot)
        ]
    }

    public static func blocks(_ items: [ReviewReadinessItem]) -> Bool {
        items.contains { $0.severity == .red }
    }

    private static func buildItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        guard let selectedBuildID = snapshot.selectedBuildID,
              let build = snapshot.builds.first(where: { $0.id == selectedBuildID }) else {
            return ReviewReadinessItem(kind: .buildValid, severity: .red)
        }
        let isValid = build.processingState == "VALID"
        return ReviewReadinessItem(kind: .buildValid, severity: isValid ? .green : .red, detail: build.buildNumber)
    }

    private static func whatsNewItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        let supportsWhatsNew = snapshot.localizations.contains { $0.whatsNew != nil }
        guard supportsWhatsNew else {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .green)
        }
        func filled(_ loc: ASCAppStoreVersionLocalization) -> Bool {
            (loc.whatsNew?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
        let applicable = snapshot.localizations.filter { $0.whatsNew != nil }
        let emptyLocales = applicable.filter { !filled($0) }.map(\.locale)
        if emptyLocales.count == applicable.count {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .red)
        } else if emptyLocales.isEmpty {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .green)
        } else {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .yellow, detail: emptyLocales.joined(separator: ", "))
        }
    }

    private static func contactItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        func present(_ value: String?) -> Bool { value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        let detail = snapshot.reviewDetail
        let complete = present(detail?.contactFirstName) && present(detail?.contactLastName)
            && present(detail?.contactPhone) && present(detail?.contactEmail)
        return ReviewReadinessItem(kind: .reviewContactComplete, severity: complete ? .green : .red)
    }

    private static func screenshotItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        let total = snapshot.screenshotSets.reduce(0) { $0 + $1.screenshots.count }
        return ReviewReadinessItem(kind: .screenshotsPresent, severity: total > 0 ? .green : .yellow)
    }

    private static func exportComplianceItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        let waiting = snapshot.versionState == "WAITING_FOR_EXPORT_COMPLIANCE"
        return ReviewReadinessItem(kind: .exportCompliance, severity: waiting ? .red : .green)
    }
}
