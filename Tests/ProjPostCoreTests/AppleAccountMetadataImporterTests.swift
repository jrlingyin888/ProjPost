import XCTest
@testable import ProjPostCore

final class AppleAccountMetadataImporterTests: XCTestCase {
    func testParsesCommonMetadataText() throws {
        let text = """
        App Store Connect API Key
        Key ID: ABC123DEF4
        Issuer ID: 69a6de7e-1111-2222-3333-444455556666
        Team ID: TEAM123456
        """

        let metadata = try AppleAccountMetadataImporter.parse(text)

        XCTAssertEqual(metadata.keyID, "ABC123DEF4")
        XCTAssertEqual(metadata.issuerID, "69a6de7e-1111-2222-3333-444455556666")
        XCTAssertEqual(metadata.teamID, "TEAM123456")
    }

    func testReadsRTFMetadataFile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("account.rtf")
        let rtf = """
        {\\rtf1\\ansi Key ID: RTF123DEF4\\line Issuer ID: 11111111-2222-3333-4444-555555555555\\line Team ID: RTFTEAM123}
        """
        try Data(rtf.utf8).write(to: fileURL)

        let metadata = try AppleAccountMetadataImporter().importMetadata(from: fileURL)

        XCTAssertEqual(metadata.keyID, "RTF123DEF4")
        XCTAssertEqual(metadata.issuerID, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(metadata.teamID, "RTFTEAM123")
    }
}
