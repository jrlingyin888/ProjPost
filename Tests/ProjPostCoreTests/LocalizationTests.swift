import XCTest
@testable import ProjPostCore

final class LocalizationTests: XCTestCase {
    func testLocalizationStoreDefaultsToEnglishWhenNoPreferenceExists() {
        let defaults = makeDefaults()
        defaults.removeObject(forKey: LocalizationStore.userDefaultsKey)

        let store = LocalizationStore(userDefaults: defaults)

        XCTAssertEqual(store.language, .english)
    }

    func testLocalizationStorePersistsSelectedLanguage() {
        let defaults = makeDefaults()
        let store = LocalizationStore(userDefaults: defaults)

        store.language = .simplifiedChinese
        let restoredStore = LocalizationStore(userDefaults: defaults)

        XCTAssertEqual(restoredStore.language, .simplifiedChinese)
    }

    func testAppLanguageDisplayNames() {
        XCTAssertEqual(AppLanguage.english.displayName, "English")
        XCTAssertEqual(AppLanguage.simplifiedChinese.displayName, "简体中文")
    }

    func testRepresentativeEnglishStrings() {
        let strings = AppStrings(language: .english)

        XCTAssertEqual(strings.projectsTitle, "Projects")
        XCTAssertEqual(strings.chooseFolder, "Choose Folder")
        XCTAssertEqual(strings.uploadToTestFlight, "Upload to TestFlight")
        XCTAssertEqual(strings.projectStatusNotConfigured, "Not Configured")
        XCTAssertEqual(strings.betaReviewStatusWaitingForReview, "Waiting for Review")
        XCTAssertEqual(strings.configurationCheckXcodeAvailableTitle, "Xcode Available")
    }

    func testRepresentativeSimplifiedChineseStrings() {
        let strings = AppStrings(language: .simplifiedChinese)

        XCTAssertEqual(strings.projectsTitle, "项目")
        XCTAssertEqual(strings.chooseFolder, "选择文件夹")
        XCTAssertEqual(strings.uploadToTestFlight, "上传到 TestFlight")
        XCTAssertEqual(strings.projectStatusNotConfigured, "未配置")
        XCTAssertEqual(strings.betaReviewStatusWaitingForReview, "正在等待审核")
        XCTAssertEqual(strings.configurationCheckXcodeAvailableTitle, "Xcode 可用")
    }

    func testGuideLanguageMapsFromAppLanguage() {
        XCTAssertEqual(AppLanguage.english.appleAccountGuideLanguage, .english)
        XCTAssertEqual(AppLanguage.simplifiedChinese.appleAccountGuideLanguage, .chinese)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LocalizationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
