import XCTest
@testable import ProjPostCore

final class AppleAccountGuideContentTests: XCTestCase {
    func testGuideCoversRequiredCredentialFields() {
        let allText = AppleAccountGuideContent.sections
            .flatMap { [$0.title] + $0.steps }
            .joined(separator: " ")

        XCTAssertTrue(allText.contains(".p8"))
        XCTAssertTrue(allText.contains("Key ID"))
        XCTAssertTrue(allText.contains("Issuer ID"))
        XCTAssertTrue(allText.contains("Team ID"))
        XCTAssertTrue(allText.contains("Keychain"))
    }

    func testGuideDeclaresBundledScreenshotResources() {
        XCTAssertEqual(AppleAccountGuideContent.screenshots.map(\.resourceName), [
            "app-store-connect-api-key",
            "apple-developer-team-id"
        ])
        XCTAssertEqual(AppleAccountGuideContent.screenshots.map(\.subdirectory), [
            "AppleAccountGuide",
            "AppleAccountGuide"
        ])
    }
}
