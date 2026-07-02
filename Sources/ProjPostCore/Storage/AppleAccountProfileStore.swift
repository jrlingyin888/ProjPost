import Foundation

public protocol AppleAccountProfileStoreProtocol {
    func load() throws -> [AppleAccountProfile]
    func save(_ profiles: [AppleAccountProfile]) throws
}

public final class AppleAccountProfileStore {
    private let fileURL: URL
    private let fileSystem: FileSysteming
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, fileSystem: FileSysteming = LocalFileSystem()) {
        self.fileURL = fileURL
        self.fileSystem = fileSystem
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public static func defaultStore(fileSystem: FileSysteming = LocalFileSystem()) -> AppleAccountProfileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("ProjPost", isDirectory: true).appendingPathComponent("accounts.json")
        return AppleAccountProfileStore(fileURL: url, fileSystem: fileSystem)
    }

    public func load() throws -> [AppleAccountProfile] {
        guard fileSystem.fileExists(fileURL) else { return [] }
        let data = try fileSystem.readData(fileURL)
        return try decoder.decode([AppleAccountProfile].self, from: data)
    }

    public func save(_ profiles: [AppleAccountProfile]) throws {
        let data = try encoder.encode(profiles)
        try fileSystem.writeData(data, to: fileURL)
    }
}

extension AppleAccountProfileStore: AppleAccountProfileStoreProtocol {}
