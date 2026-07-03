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
    private static let systemPath = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"

    public init() {}

    public func run(_ command: Command) async throws -> CommandResult {
        try await Task.detached(priority: .utility) {
            try self.runSynchronously(command)
        }.value
    }

    private func runSynchronously(_ command: Command) throws -> CommandResult {
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectory
        process.environment = resolvedEnvironment(for: command)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let stdout = LockedData()
        let stderr = LockedData()
        let outputReaders = DispatchGroup()

        outputReaders.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout.set(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            outputReaders.leave()
        }

        outputReaders.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr.set(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            outputReaders.leave()
        }

        process.waitUntilExit()
        outputReaders.wait()

        let stdoutText = String(data: stdout.value, encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.value, encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, stdout: stdoutText, stderr: stderrText)
    }

    private func resolvedEnvironment(for command: Command) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        command.environment.forEach { key, value in
            environment[key] = value
        }
        environment["PATH"] = mergedPath(environment["PATH"])
        return environment
    }

    private func mergedPath(_ path: String?) -> String {
        var components = (path ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        for component in Self.systemPath.split(separator: ":").map(String.init) where !components.contains(component) {
            components.append(component)
        }

        return components.joined(separator: ":")
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }
}
