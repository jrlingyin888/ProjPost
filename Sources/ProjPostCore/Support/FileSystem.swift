import Foundation

public protocol FileSysteming {
    func fileExists(_ url: URL) -> Bool
    func contentsOfDirectory(_ url: URL) throws -> [String]
    func createDirectory(_ url: URL) throws
    func readData(_ url: URL) throws -> Data
    func writeData(_ data: Data, to url: URL) throws
}

public final class LocalFileSystem: FileSysteming {
    public init() {}

    public func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func contentsOfDirectory(_ url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path)
    }

    public func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func readData(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try createDirectory(parent)
        try data.write(to: url, options: [.atomic])
    }
}
