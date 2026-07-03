import XCTest
@testable import ProjPostCore

final class AppleAccountGuideContentTests: XCTestCase {
    func testDefaultGuideLanguageIsEnglish() {
        XCTAssertEqual(AppleAccountGuideContent.defaultLanguage, .english)
        XCTAssertEqual(AppleAccountGuideContent.title(for: .english), "Apple Account Guide")
        XCTAssertEqual(AppleAccountGuideContent.languageDisplayName(.english), "English")
    }

    func testEnglishGuideCoversRequiredCredentialFields() {
        let allText = AppleAccountGuideContent.sections(for: .english)
            .flatMap { [$0.title] + $0.steps }
            .joined(separator: " ")

        XCTAssertTrue(allText.contains(".p8"))
        XCTAssertTrue(allText.contains("Key ID"))
        XCTAssertTrue(allText.contains("Issuer ID"))
        XCTAssertTrue(allText.contains("Team ID"))
        XCTAssertTrue(allText.contains("Keychain"))
    }

    func testChineseGuideCoversRequiredCredentialFields() {
        let allText = AppleAccountGuideContent.sections(for: .chinese)
            .flatMap { [$0.title] + $0.steps }
            .joined(separator: " ")

        XCTAssertTrue(allText.contains(".p8"))
        XCTAssertTrue(allText.contains("Key ID"))
        XCTAssertTrue(allText.contains("Issuer ID"))
        XCTAssertTrue(allText.contains("Team ID"))
        XCTAssertTrue(allText.contains("钥匙串"))
        XCTAssertEqual(AppleAccountGuideContent.title(for: .chinese), "Apple 账号指引")
        XCTAssertEqual(AppleAccountGuideContent.languageDisplayName(.chinese), "中文")
    }

    func testGuideDeclaresBundledScreenshotResources() {
        XCTAssertEqual(AppleAccountGuideContent.screenshots(for: .english).map(\.resourceName), [
            "app-store-connect-api-key",
            "apple-developer-team-id"
        ])
        XCTAssertEqual(AppleAccountGuideContent.screenshots(for: .english).map(\.subdirectory), [
            nil,
            nil
        ])
    }
}
