import Foundation

public struct UploadEvent: Equatable {
    public var step: UploadStep
    public var message: String
    public var succeeded: Bool

    public init(step: UploadStep, message: String, succeeded: Bool) {
        self.step = step
        self.message = message
        self.succeeded = succeeded
    }
}

public enum UploadJobRunnerError: Error, Equatable {
    case commandFailed(step: UploadStep, message: String)
    case missingExportedIPA(exportPath: String)
    case ambiguousExportedIPAs(exportPath: String, candidates: [String])
}

public final class UploadJobRunner {
    private let commandRunner: CommandRunning
    private let commandBuilder: UploadCommandBuilder
    private let credentialVault: CredentialVault
    private let exportOptionsWriter: ExportOptionsPlistWriter
    private let fileSystem: FileSysteming

    public init(
        commandRunner: CommandRunning,
        commandBuilder: UploadCommandBuilder,
        fileSystem: FileSysteming = LocalFileSystem(),
        credentialVault: CredentialVault = KeychainCredentialVault(),
        exportOptionsWriter: ExportOptionsPlistWriter? = nil
    ) {
        self.commandRunner = commandRunner
        self.commandBuilder = commandBuilder
        self.fileSystem = fileSystem
        self.credentialVault = credentialVault
        self.exportOptionsWriter = exportOptionsWriter ?? ExportOptionsPlistWriter(fileSystem: fileSystem)
    }

    public func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile, keyPath: String) async throws -> [UploadEvent] {
        try await runLocalUpload(
            project: project,
            account: account,
            authenticationKeyURL: URL(fileURLWithPath: keyPath)
        )
    }

    public func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile) async throws -> [UploadEvent] {
        let privateKey = try credentialVault.privateKey(for: account.id)
        let keyDirectory = temporaryAuthenticationKeyDirectory()
        let keyURL = keyDirectory.appendingPathComponent("AuthKey_\(account.keyID).p8")

        try fileSystem.createDirectory(keyDirectory)
        try fileSystem.writeSensitiveData(Data(privateKey.utf8), to: keyURL)
        defer {
            try? fileSystem.removeItem(keyDirectory)
        }

        return try await runLocalUpload(project: project, account: account, authenticationKeyURL: keyURL)
    }

    private func runLocalUpload(
        project: ProjectProfile,
        account: AppleAccountProfile,
        authenticationKeyURL: URL
    ) async throws -> [UploadEvent] {
        let buildDir = URL(fileURLWithPath: project.projectPath).appendingPathComponent("build", isDirectory: true)
        let archivePath = buildDir.appendingPathComponent("\(project.name).xcarchive")
        let exportPath = buildDir.appendingPathComponent("export", isDirectory: true)
        let exportOptionsPlist = buildDir.appendingPathComponent("ExportOptions.plist")

        var events: [UploadEvent] = []

        let archiveResult = try await commandRunner.run(try commandBuilder.archiveCommand(project: project, archivePath: archivePath))
        try append(result: archiveResult, step: .archive, to: &events)

        let effectiveTeamID = project.teamID ?? account.teamID
        try exportOptionsWriter.write(teamID: effectiveTeamID, to: exportOptionsPlist)

        let exportResult = try await commandRunner.run(
            commandBuilder.exportCommand(
                project: project,
                account: account,
                keyPath: authenticationKeyURL.path,
                archivePath: archivePath,
                exportPath: exportPath,
                exportOptionsPlist: exportOptionsPlist
            )
        )
        try append(result: exportResult, step: .exportIPA, to: &events)

        let ipaPath = try discoverExportedIPA(in: exportPath)
        let uploadResult = try await commandRunner.run(commandBuilder.uploadCommand(ipaPath: ipaPath, account: account))
        try append(result: uploadResult, step: .upload, to: &events)

        return events
    }

    private func append(result: CommandResult, step: UploadStep, to events: inout [UploadEvent]) throws {
        let output = result.stderr.isEmpty ? result.stdout : [result.stderr, result.stdout.isEmpty ? nil : "stdout:\n\(result.stdout)"].compactMap { $0 }.joined(separator: "\n\n")
        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let succeeded = result.exitCode == 0

        events.append(UploadEvent(step: step, message: message, succeeded: succeeded))

        guard succeeded else {
            throw UploadJobRunnerError.commandFailed(step: step, message: message)
        }
    }

    private func temporaryAuthenticationKeyDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("projpost-upload-\(UUID().uuidString)", isDirectory: true)
    }

    private func discoverExportedIPA(in exportPath: URL) throws -> URL {
        let candidates = try fileSystem.contentsOfDirectory(exportPath)
            .filter { $0.lowercased().hasSuffix(".ipa") }
            .sorted()

        switch candidates.count {
        case 1:
            return exportPath.appendingPathComponent(candidates[0])
        case 0:
            throw UploadJobRunnerError.missingExportedIPA(exportPath: exportPath.path)
        default:
            throw UploadJobRunnerError.ambiguousExportedIPAs(exportPath: exportPath.path, candidates: candidates)
        }
    }
}
