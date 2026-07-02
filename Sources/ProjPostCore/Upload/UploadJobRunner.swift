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
}

public final class UploadJobRunner {
    private let commandRunner: CommandRunning
    private let commandBuilder: UploadCommandBuilder
    private let exportOptionsWriter: ExportOptionsPlistWriter

    public init(
        commandRunner: CommandRunning,
        commandBuilder: UploadCommandBuilder,
        exportOptionsWriter: ExportOptionsPlistWriter = ExportOptionsPlistWriter()
    ) {
        self.commandRunner = commandRunner
        self.commandBuilder = commandBuilder
        self.exportOptionsWriter = exportOptionsWriter
    }

    public func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile, keyPath: String) async throws -> [UploadEvent] {
        let buildDir = URL(fileURLWithPath: project.projectPath).appendingPathComponent("build", isDirectory: true)
        let archivePath = buildDir.appendingPathComponent("\(project.name).xcarchive")
        let exportPath = buildDir.appendingPathComponent("export", isDirectory: true)
        let exportOptionsPlist = buildDir.appendingPathComponent("ExportOptions.plist")
        let ipaPath = exportPath.appendingPathComponent("\(project.name).ipa")

        var events: [UploadEvent] = []

        let archiveResult = try await commandRunner.run(try commandBuilder.archiveCommand(project: project, archivePath: archivePath))
        try append(result: archiveResult, step: .archive, to: &events)

        try exportOptionsWriter.write(teamID: project.teamID, to: exportOptionsPlist)

        let exportResult = try await commandRunner.run(
            commandBuilder.exportCommand(
                project: project,
                account: account,
                keyPath: keyPath,
                archivePath: archivePath,
                exportPath: exportPath,
                exportOptionsPlist: exportOptionsPlist
            )
        )
        try append(result: exportResult, step: .exportIPA, to: &events)

        let uploadResult = try await commandRunner.run(commandBuilder.uploadCommand(ipaPath: ipaPath, account: account))
        try append(result: uploadResult, step: .upload, to: &events)

        return events
    }

    private func append(result: CommandResult, step: UploadStep, to events: inout [UploadEvent]) throws {
        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let succeeded = result.exitCode == 0

        events.append(UploadEvent(step: step, message: message, succeeded: succeeded))

        guard succeeded else {
            throw UploadJobRunnerError.commandFailed(step: step, message: message)
        }
    }
}
