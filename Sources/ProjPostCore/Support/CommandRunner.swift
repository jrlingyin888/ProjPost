import Foundation

public struct Command: Equatable {
    public var executableURL: URL
    public var arguments: [String]
    public var workingDirectory: URL?
    public var environment: [String: String]

    public init(executableURL: URL, arguments: [String], workingDirectory: URL? = nil, environment: [String: String] = [:]) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

public struct CommandResult: Equatable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol CommandRunning {
    func run(_ command: Command) async throws -> CommandResult
}

public final class ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ command: Command) async throws -> CommandResult {
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectory
        process.environment = command.environment.isEmpty ? nil : command.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
