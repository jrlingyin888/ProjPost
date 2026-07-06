import Combine
import Foundation

public final class LocalizationStore: ObservableObject {
    public static let userDefaultsKey = "JJPost.selectedLanguage"

    @Published public var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: Self.userDefaultsKey),
           let savedLanguage = AppLanguage(rawValue: rawValue) {
            language = savedLanguage
        } else {
            language = .english
        }
    }
}
