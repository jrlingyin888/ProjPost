import Foundation

public enum UploadCommandBuilderError: Error, Equatable {
    case missingScheme
    case missingWorkspaceOrProject
}

public struct UploadCommandBuilder {
    public init() {}

    public func archiveCommand(project: ProjectProfile, archivePath: URL) throws -> Command {
        guard let scheme = project.scheme else {
            throw UploadCommandBuilderError.missingScheme
        }

        var arguments = ["archive"]
        if let workspacePath = project.workspacePath {
            arguments += ["-workspace", workspacePath]
        } else if let projectFilePath = project.projectFilePath {
            arguments += ["-project", projectFilePath]
        } else {
            throw UploadCommandBuilderError.missingWorkspaceOrProject
        }

        arguments += [
            "-scheme", scheme,
            "-configuration", project.configuration,
            "-archivePath", archivePath.path,
            "-destination", "generic/platform=iOS",
            "-allowProvisioningUpdates"
        ]

        return Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
            arguments: arguments,
            workingDirectory: URL(fileURLWithPath: project.projectPath)
        )
    }

    public func exportCommand(
        project: ProjectProfile,
        account: AppleAccountProfile,
        keyPath: String,
        archivePath: URL,
        exportPath: URL,
        exportOptionsPlist: URL
    ) -> Command {
        Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
            arguments: [
                "-exportArchive",
                "-archivePath", archivePath.path,
                "-exportPath", exportPath.path,
                "-exportOptionsPlist", exportOptionsPlist.path,
                "-allowProvisioningUpdates",
                "-authenticationKeyIssuerID", account.issuerID,
                "-authenticationKeyID", account.keyID,
                "-authenticationKeyPath", keyPath
            ],
            workingDirectory: URL(fileURLWithPath: project.projectPath)
        )
    }

    public func uploadCommand(ipaPath: URL, account: AppleAccountProfile) -> Command {
        Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: [
                "altool",
                "--upload-app",
                "-f", ipaPath.path,
                "-t", "ios",
                "--apiKey", account.keyID,
                "--apiIssuer", account.issuerID
            ]
        )
    }
}
