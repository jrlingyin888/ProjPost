import Foundation

public struct ProjectMutationRequest: Equatable {
    public var projectRoot: URL
    public var pbxprojURL: URL
    public var infoPlistURL: URL?
    public var currentBundleID: String?
    public var newBundleID: String?
    public var currentVersion: String?
    public var newVersion: String?
    public var currentBuildNumber: String?
    public var newBuildNumber: String?

    public init(
        projectRoot: URL,
        pbxprojURL: URL,
        infoPlistURL: URL?,
        currentBundleID: String?,
        newBundleID: String?,
        currentVersion: String?,
        newVersion: String?,
        currentBuildNumber: String?,
        newBuildNumber: String?
    ) {
        self.projectRoot = projectRoot
        self.pbxprojURL = pbxprojURL
        self.infoPlistURL = infoPlistURL
        self.currentBundleID = currentBundleID
        self.newBundleID = newBundleID
        self.currentVersion = currentVersion
        self.newVersion = newVersion
        self.currentBuildNumber = currentBuildNumber
        self.newBuildNumber = newBuildNumber
    }
}

public struct ProjectMutationChange: Equatable {
    public var summary: String
    public var oldValue: String?
    public var newValue: String?
}

public struct ProjectMutationPlan: Equatable {
    public var request: ProjectMutationRequest
    public var backupDirectory: URL
    public var filesToBackup: [URL]
    public var changes: [ProjectMutationChange]
}

public enum ProjectMutatorError: Error, Equatable {
    case missingPbxproj(URL)
    case noChanges
}

public final class ProjectMutator {
    private let fileSystem: FileSysteming
    private let backupRoot: URL

    public init(fileSystem: FileSysteming = LocalFileSystem(), backupRoot: URL) {
        self.fileSystem = fileSystem
        self.backupRoot = backupRoot
    }

    public func plan(request: ProjectMutationRequest) throws -> ProjectMutationPlan {
        guard fileSystem.fileExists(request.pbxprojURL) else {
            throw ProjectMutatorError.missingPbxproj(request.pbxprojURL)
        }

        var changes: [ProjectMutationChange] = []
        appendChange(&changes, label: "Bundle ID", old: request.currentBundleID, new: request.newBundleID)
        appendChange(&changes, label: "Version", old: request.currentVersion, new: request.newVersion)
        appendChange(&changes, label: "Build Number", old: request.currentBuildNumber, new: request.newBuildNumber)

        guard !changes.isEmpty else {
            throw ProjectMutatorError.noChanges
        }

        var files = [request.pbxprojURL]
        if let infoPlistURL = request.infoPlistURL, fileSystem.fileExists(infoPlistURL) {
            files.append(infoPlistURL)
        }

        let formatter = ISO8601DateFormatter()
        let folderName = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDirectory = backupRoot.appendingPathComponent(folderName, isDirectory: true)

        return ProjectMutationPlan(
            request: request,
            backupDirectory: backupDirectory,
            filesToBackup: files,
            changes: changes
        )
    }

    public func apply(_ plan: ProjectMutationPlan) throws {
        try backup(plan)

        var pbxData = try fileSystem.readData(plan.request.pbxprojURL)
        var pbxText = String(data: pbxData, encoding: .utf8) ?? ""

        if let old = plan.request.currentBundleID, let new = plan.request.newBundleID, old != new {
            pbxText = pbxText.replacingOccurrences(
                of: "PRODUCT_BUNDLE_IDENTIFIER = \(old);",
                with: "PRODUCT_BUNDLE_IDENTIFIER = \(new);"
            )
        }

        if let old = plan.request.currentVersion, let new = plan.request.newVersion, old != new {
            pbxText = pbxText.replacingOccurrences(
                of: "MARKETING_VERSION = \(old);",
                with: "MARKETING_VERSION = \(new);"
            )
        }

        if let old = plan.request.currentBuildNumber, let new = plan.request.newBuildNumber, old != new {
            pbxText = pbxText.replacingOccurrences(
                of: "CURRENT_PROJECT_VERSION = \(old);",
                with: "CURRENT_PROJECT_VERSION = \(new);"
            )
        }

        pbxData = Data(pbxText.utf8)
        try fileSystem.writeData(pbxData, to: plan.request.pbxprojURL)
    }

    private func backup(_ plan: ProjectMutationPlan) throws {
        try fileSystem.createDirectory(plan.backupDirectory)

        for file in plan.filesToBackup {
            let data = try fileSystem.readData(file)
            let backupFile = plan.backupDirectory.appendingPathComponent(file.lastPathComponent)
            try fileSystem.writeData(data, to: backupFile)
        }

        let summary = plan.changes.map(\.summary).joined(separator: "\n")
        try fileSystem.writeData(Data(summary.utf8), to: plan.backupDirectory.appendingPathComponent("changes.txt"))
    }

    private func appendChange(_ changes: inout [ProjectMutationChange], label: String, old: String?, new: String?) {
        guard let new, old != new else { return }
        changes.append(
            ProjectMutationChange(
                summary: "\(label): \(old ?? "-") -> \(new)",
                oldValue: old,
                newValue: new
            )
        )
    }
}
