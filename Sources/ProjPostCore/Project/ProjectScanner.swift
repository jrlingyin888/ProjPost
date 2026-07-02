import Foundation

public struct ProjectScanResult: Equatable {
    public var projectPath: URL
    public var workspacePath: URL?
    public var projectFilePath: URL?
    public var schemes: [String]
    public var selectedScheme: String?
    public var bundleID: String?
    public var version: String?
    public var buildNumber: String?
    public var teamID: String?

    public func toProjectProfile(nameOverride: String? = nil) -> ProjectProfile {
        ProjectProfile(
            name: nameOverride ?? projectPath.lastPathComponent,
            projectPath: projectPath.path,
            workspacePath: workspacePath?.path,
            projectFilePath: projectFilePath?.path,
            scheme: selectedScheme,
            configuration: "Release",
            bundleID: bundleID,
            version: version,
            buildNumber: buildNumber,
            teamID: teamID,
            selectedAccountID: nil,
            lastUpload: nil
        )
    }
}

public final class ProjectScanner {
    private let commandRunner: CommandRunning
    private let fileSystem: FileSysteming

    public init(commandRunner: CommandRunning, fileSystem: FileSysteming = LocalFileSystem()) {
        self.commandRunner = commandRunner
        self.fileSystem = fileSystem
    }

    public func scan(projectPath: URL) async throws -> ProjectScanResult {
        let workspace = findFirst(projectPath: projectPath, suffix: ".xcworkspace")
        let projectFile = findFirst(projectPath: projectPath, suffix: ".xcodeproj")
        let listJSON = try await runXcodebuildList(projectPath: projectPath, workspace: workspace, projectFile: projectFile)
        let schemes = try parseSchemes(from: listJSON)
        let selectedScheme = schemes.first
        let settings = try await runBuildSettings(projectPath: projectPath, workspace: workspace, projectFile: projectFile, scheme: selectedScheme)

        return ProjectScanResult(
            projectPath: projectPath,
            workspacePath: workspace,
            projectFilePath: projectFile,
            schemes: schemes,
            selectedScheme: selectedScheme,
            bundleID: settings["PRODUCT_BUNDLE_IDENTIFIER"],
            version: settings["MARKETING_VERSION"],
            buildNumber: settings["CURRENT_PROJECT_VERSION"],
            teamID: settings["DEVELOPMENT_TEAM"]
        )
    }

    private func findFirst(projectPath: URL, suffix: String) -> URL? {
        let candidates = (try? fileSystem.contentsOfDirectory(projectPath)) ?? []
        return candidates.sorted().first { $0.hasSuffix(suffix) }.map { projectPath.appendingPathComponent($0) }
    }

    private func runXcodebuildList(projectPath: URL, workspace: URL?, projectFile: URL?) async throws -> String {
        var args = ["-list", "-json"]
        if let workspace {
            args += ["-workspace", workspace.path]
        } else if let projectFile {
            args += ["-project", projectFile.path]
        }
        let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: args, workingDirectory: projectPath))
        guard result.exitCode == 0 else { throw ProjectScannerError.commandFailed(result.stderr) }
        return result.stdout
    }

    private func runBuildSettings(projectPath: URL, workspace: URL?, projectFile: URL?, scheme: String?) async throws -> [String: String] {
        guard let scheme else { return [:] }
        var args = ["-showBuildSettings", "-json", "-scheme", scheme]
        if let workspace {
            args += ["-workspace", workspace.path]
        } else if let projectFile {
            args += ["-project", projectFile.path]
        }
        let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: args, workingDirectory: projectPath))
        guard result.exitCode == 0 else { throw ProjectScannerError.commandFailed(result.stderr) }
        return try parseBuildSettings(from: result.stdout)
    }

    private func parseSchemes(from json: String) throws -> [String] {
        let data = Data(json.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let workspaceSchemes = ((object?["workspace"] as? [String: Any])?["schemes"] as? [String]) ?? []
        let projectSchemes = ((object?["project"] as? [String: Any])?["schemes"] as? [String]) ?? []
        return workspaceSchemes.isEmpty ? projectSchemes : workspaceSchemes
    }

    private func parseBuildSettings(from json: String) throws -> [String: String] {
        let data = Data(json.utf8)
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let settings = array?.first?["buildSettings"] as? [String: Any]
        return settings?.compactMapValues { $0 as? String } ?? [:]
    }
}

public enum ProjectScannerError: Error, Equatable {
    case commandFailed(String)
}
