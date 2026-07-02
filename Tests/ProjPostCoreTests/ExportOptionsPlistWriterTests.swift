import XCTest
@testable import ProjPostCore

final class ExportOptionsPlistWriterTests: XCTestCase {
    func testWriterCreatesAppStoreConnectExportOptions() throws {
        let fileSystem = MemoryFileSystem()
        let writer = ExportOptionsPlistWriter(fileSystem: fileSystem)
        let url = URL(fileURLWithPath: "/tmp/ExportOptions.plist")

        try writer.write(teamID: "ABCDE12345", to: url)

        let data = try XCTUnwrap(fileSystem.written[url])
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(object?["method"] as? String, "app-store-connect")
        XCTAssertEqual(object?["destination"] as? String, "export")
        XCTAssertEqual(object?["signingStyle"] as? String, "automatic")
        XCTAssertEqual(object?["teamID"] as? String, "ABCDE12345")
        XCTAssertEqual(object?["uploadSymbols"] as? Bool, true)
    }
}

private final class MemoryFileSystem: FileSysteming {
    var written: [URL: Data] = [:]

    func fileExists(_ url: URL) -> Bool { written[url] != nil }
    func contentsOfDirectory(_ url: URL) throws -> [String] { [] }
    func createDirectory(_ url: URL) throws {}
    func readData(_ url: URL) throws -> Data { written[url] ?? Data() }
    func writeData(_ data: Data, to url: URL) throws { written[url] = data }
}
