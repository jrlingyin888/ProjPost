import Foundation

public struct ExportOptionsPlistWriter {
    private let fileSystem: FileSysteming

    public init(fileSystem: FileSysteming = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func write(teamID: String?, to url: URL) throws {
        var plist: [String: Any] = [
            "destination": "export",
            "method": "app-store-connect",
            "signingStyle": "automatic",
            "stripSwiftSymbols": true,
            "uploadSymbols": true
        ]

        if let teamID, !teamID.isEmpty {
            plist["teamID"] = teamID
        }

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try fileSystem.writeData(data, to: url)
    }
}
