import Foundation

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
        lastUpload: UploadSummary?
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
