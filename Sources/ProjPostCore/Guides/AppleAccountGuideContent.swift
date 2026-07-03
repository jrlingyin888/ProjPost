import Foundation

public enum AppleAccountGuideLanguage: String, CaseIterable, Equatable, Identifiable {
    case english
    case chinese

    public var id: String { rawValue }
}

public struct AppleAccountGuideSection: Equatable, Identifiable {
    public var id: String
    public var title: String
    public var steps: [String]

    public init(id: String, title: String, steps: [String]) {
        self.id = id
        self.title = title
        self.steps = steps
    }
}

public struct AppleAccountGuideScreenshot: Equatable, Identifiable {
    public var id: String
    public var resourceName: String
    public var subdirectory: String?
    public var caption: String

    public init(id: String, resourceName: String, subdirectory: String? = nil, caption: String) {
        self.id = id
        self.resourceName = resourceName
        self.subdirectory = subdirectory
        self.caption = caption
    }
}

public enum AppleAccountGuideContent {
    public static let defaultLanguage: AppleAccountGuideLanguage = .english
    public static let appStoreConnectURL = URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!
    public static let developerMembershipURL = URL(string: "https://developer.apple.com/account")!

    public static var sections: [AppleAccountGuideSection] {
        sections(for: defaultLanguage)
    }

    public static var screenshots: [AppleAccountGuideScreenshot] {
        screenshots(for: defaultLanguage)
    }

    public static func languageDisplayName(_ language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }

    public static func title(for language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "Apple Account Guide"
        case .chinese:
            return "Apple 账号指引"
        }
    }

    public static func subtitle(for language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "Find the .p8 key, Key ID, Issuer ID, and Team ID for JJPost."
        case .chinese:
            return "找到 JJPost 需要的 .p8、Key ID、Issuer ID 和 Team ID。"
        }
    }

    public static func doneButtonTitle(for language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "Done"
        case .chinese:
            return "完成"
        }
    }

    public static func appStoreConnectLinkTitle(for language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "Open App Store Connect API"
        case .chinese:
            return "打开 App Store Connect API"
        }
    }

    public static func developerAccountLinkTitle(for language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "Open Apple Developer Account"
        case .chinese:
            return "打开 Apple Developer 账号"
        }
    }

    public static func openImageTitle(for language: AppleAccountGuideLanguage) -> String {
        switch language {
        case .english:
            return "Click to preview"
        case .chinese:
            return "点击预览大图"
        }
    }

    public static func sections(for language: AppleAccountGuideLanguage) -> [AppleAccountGuideSection] {
        switch language {
        case .english:
            return englishSections
        case .chinese:
            return chineseSections
        }
    }

    public static func screenshots(for language: AppleAccountGuideLanguage) -> [AppleAccountGuideScreenshot] {
        switch language {
        case .english:
            return englishScreenshots
        case .chinese:
            return chineseScreenshots
        }
    }

    private static let englishSections: [AppleAccountGuideSection] = [
        AppleAccountGuideSection(
            id: "api-key",
            title: "App Store Connect API key",
            steps: [
                "Open App Store Connect > Users and Access > Integrations > App Store Connect API.",
                "Create or select a Team key with enough access for TestFlight upload.",
                "Copy the Issuer ID shown near the App Store Connect API key list.",
                "Copy the Key ID from the generated key row.",
                "Download the .p8 private key once and import it with Import .p8."
            ]
        ),
        AppleAccountGuideSection(
            id: "team-id",
            title: "Apple Developer Team ID",
            steps: [
                "Open Apple Developer Account and choose the correct team.",
                "Open Membership details.",
                "Copy the Team ID and enter it in JJPost."
            ]
        ),
        AppleAccountGuideSection(
            id: "security",
            title: "Private key safety",
            steps: [
                "Apple lets you download the .p8 file only once.",
                "JJPost imports the .p8 content into Keychain and does not display the private key text."
            ]
        )
    ]

    private static let chineseSections: [AppleAccountGuideSection] = [
        AppleAccountGuideSection(
            id: "api-key",
            title: "App Store Connect API 密钥",
            steps: [
                "打开 App Store Connect > 用户和访问 > 集成 > App Store Connect API。",
                "创建或选择一个有足够权限执行 TestFlight 上传的团队密钥。",
                "复制 API 密钥列表上方显示的 Issuer ID。",
                "复制已生成密钥所在行里的 Key ID。",
                "下载 .p8 私钥文件，并在 JJPost 里点击 Import .p8 导入。"
            ]
        ),
        AppleAccountGuideSection(
            id: "team-id",
            title: "Apple Developer Team ID",
            steps: [
                "打开 Apple Developer Account，并确认选择的是正确团队。",
                "进入会员资格详情信息。",
                "复制 Team ID，并填入 JJPost。"
            ]
        ),
        AppleAccountGuideSection(
            id: "security",
            title: "私钥安全",
            steps: [
                "Apple 的 .p8 文件只能下载一次，请妥善保存。",
                "JJPost 会把 .p8 内容导入钥匙串，不会显示私钥文本。"
            ]
        )
    ]

    private static let englishScreenshots: [AppleAccountGuideScreenshot] = [
        AppleAccountGuideScreenshot(
            id: "api-key-page",
            resourceName: "app-store-connect-api-key",
            caption: "Issuer ID is shown above the active App Store Connect API keys. Key ID is shown in the key row."
        ),
        AppleAccountGuideScreenshot(
            id: "team-id-page",
            resourceName: "apple-developer-team-id",
            caption: "Team ID is shown in Apple Developer membership details."
        )
    ]

    private static let chineseScreenshots: [AppleAccountGuideScreenshot] = [
        AppleAccountGuideScreenshot(
            id: "api-key-page",
            resourceName: "app-store-connect-api-key",
            caption: "Issuer ID 显示在有效的 App Store Connect API 密钥列表上方，Key ID 显示在密钥所在行。"
        ),
        AppleAccountGuideScreenshot(
            id: "team-id-page",
            resourceName: "apple-developer-team-id",
            caption: "Team ID 显示在 Apple Developer 的会员资格详情信息中。"
        )
    ]
}
