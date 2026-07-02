import Foundation
import PathKit
import XcodeProj

public struct ProjectMutationRequest: Equatable {
    public var projectRoot: URL
    public var pbxprojURL: URL
    public var infoPlistURL: URL?
    public var targetName: String?
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
        targetName: String? = nil,
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
        self.targetName = targetName
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
    case missingCurrentValue(String)
    case expectedSettingNotFound(String)
    case targetNotFound
    case ambiguousTarget([String])
}

public final class ProjectMutator {
    private let fileSystem: FileSysteming
    private let backupRoot: URL

    public init(fileSystem: FileSysteming = LocalFileSystem(), backupRoot: URL) {
        self.fileSystem = fileSystem
        self.backupRoot = backupRoot
    }

    public func request(
        from project: ProjectProfile,
        targetBundleID: String?,
        targetVersion: String?,
        targetBuildNumber: String?,
        infoPlistURL: URL?
    ) throws -> ProjectMutationRequest {
        let projectRoot = URL(fileURLWithPath: project.projectPath)
        let pbxprojURL = resolvePBXProjURL(project: project, projectRoot: projectRoot)

        return ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: pbxprojURL,
            infoPlistURL: infoPlistURL,
            targetName: project.scheme,
            currentBundleID: project.bundleID,
            newBundleID: targetBundleID,
            currentVersion: project.version,
            newVersion: targetVersion,
            currentBuildNumber: project.buildNumber,
            newBuildNumber: targetBuildNumber
        )
    }

    public func plan(
        project: ProjectProfile,
        targetBundleID: String?,
        targetVersion: String?,
        targetBuildNumber: String?,
        infoPlistURL: URL?
    ) throws -> ProjectMutationPlan {
        let request = try request(
            from: project,
            targetBundleID: targetBundleID,
            targetVersion: targetVersion,
            targetBuildNumber: targetBuildNumber,
            infoPlistURL: infoPlistURL
        )
        return try plan(request: request)
    }

    public func plan(request: ProjectMutationRequest) throws -> ProjectMutationPlan {
        guard fileSystem.fileExists(request.pbxprojURL) else {
            throw ProjectMutatorError.missingPbxproj(request.pbxprojURL)
        }

        var changes: [ProjectMutationChange] = []
        try appendChange(&changes, label: "Bundle ID", old: request.currentBundleID, new: request.newBundleID)
        try appendChange(&changes, label: "Version", old: request.currentVersion, new: request.newVersion)
        try appendChange(&changes, label: "Build Number", old: request.currentBuildNumber, new: request.newBuildNumber)

        guard !changes.isEmpty else {
            throw ProjectMutatorError.noChanges
        }

        var files = [request.pbxprojURL]
        if let infoPlistURL = request.infoPlistURL, fileSystem.fileExists(infoPlistURL) {
            files.append(infoPlistURL)
        }

        let folderName = backupFolderName()
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

        let xcodeprojURL = plan.request.pbxprojURL.deletingLastPathComponent()
        let project = try XcodeProj(path: Path(xcodeprojURL.path))
        let target = try targetToMutate(in: project, request: plan.request)

        for configuration in target.buildConfigurationList?.buildConfigurations ?? [] {
            if let new = plan.request.newBundleID {
                configuration.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = new
            }
            if let new = plan.request.newVersion {
                configuration.buildSettings["MARKETING_VERSION"] = new
            }
            if let new = plan.request.newBuildNumber {
                configuration.buildSettings["CURRENT_PROJECT_VERSION"] = new
            }
        }

        try project.write(path: Path(xcodeprojURL.path), override: true)
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

    private func appendChange(_ changes: inout [ProjectMutationChange], label: String, old: String?, new: String?) throws {
        guard let new else { return }
        guard let old else {
            throw ProjectMutatorError.missingCurrentValue(label)
        }
        guard old != new else { return }
        changes.append(
            ProjectMutationChange(
                summary: "\(label): \(old) -> \(new)",
                oldValue: old,
                newValue: new
            )
        )
    }

    private func resolvePBXProjURL(project: ProjectProfile, projectRoot: URL) -> URL {
        if let projectFilePath = project.projectFilePath {
            return URL(fileURLWithPath: projectFilePath).appendingPathComponent("project.pbxproj")
        }

        return projectRoot.appendingPathComponent("\(project.name).xcodeproj/project.pbxproj")
    }

    private func backupFolderName() -> String {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "\(timestamp)-\(UUID().uuidString)"
    }

    private func targetToMutate(in project: XcodeProj, request: ProjectMutationRequest) throws -> PBXNativeTarget {
        let targets = project.pbxproj.nativeTargets

        if let targetName = request.targetName?.trimmingCharacters(in: .whitespacesAndNewlines), !targetName.isEmpty {
            let namedTargets = targets.filter { $0.name == targetName }
            if namedTargets.count == 1 {
                return namedTargets[0]
            }
            if namedTargets.count > 1 {
                throw ProjectMutatorError.ambiguousTarget(namedTargets.map(\.name))
            }
        }

        let matchingTargets = targets.filter { targetMatchesCurrentSettings($0, request: request) }
        switch matchingTargets.count {
        case 1:
            return matchingTargets[0]
        case 0:
            throw ProjectMutatorError.targetNotFound
        default:
            throw ProjectMutatorError.ambiguousTarget(matchingTargets.map(\.name))
        }
    }

    private func targetMatchesCurrentSettings(_ target: PBXNativeTarget, request: ProjectMutationRequest) -> Bool {
        let configurations = target.buildConfigurationList?.buildConfigurations ?? []
        guard !configurations.isEmpty else { return false }
        return configurations.contains { configuration in
            settingsMatch(configuration.buildSettings, key: "PRODUCT_BUNDLE_IDENTIFIER", expected: request.currentBundleID) &&
            settingsMatch(configuration.buildSettings, key: "MARKETING_VERSION", expected: request.currentVersion) &&
            settingsMatch(configuration.buildSettings, key: "CURRENT_PROJECT_VERSION", expected: request.currentBuildNumber)
        }
    }

    private func settingsMatch(_ settings: [String: Any], key: String, expected: String?) -> Bool {
        guard let expected else { return true }
        return settings[key] as? String == expected
    }
}
