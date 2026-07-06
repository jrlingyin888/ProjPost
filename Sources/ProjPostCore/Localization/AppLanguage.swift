import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Equatable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    public var appleAccountGuideLanguage: AppleAccountGuideLanguage {
        switch self {
        case .english:
            return .english
        case .simplifiedChinese:
            return .chinese
        }
    }
}
