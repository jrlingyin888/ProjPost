import Foundation

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
    public var subdirectory: String
    public var caption: String

    public init(id: String, resourceName: String, subdirectory: String, caption: String) {
        self.id = id
        self.resourceName = resourceName
        self.subdirectory = subdirectory
        self.caption = caption
    }
}

public enum AppleAccountGuideContent {
    public static let appStoreConnectURL = URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!
    public static let developerMembershipURL = URL(string: "https://developer.apple.com/account")!

    public static let sections: [AppleAccountGuideSection] = [
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

    public static let screenshots: [AppleAccountGuideScreenshot] = [
        AppleAccountGuideScreenshot(
            id: "api-key-page",
            resourceName: "app-store-connect-api-key",
            subdirectory: "AppleAccountGuide",
            caption: "Issuer ID is shown above the active App Store Connect API keys. Key ID is shown in the key row."
        ),
        AppleAccountGuideScreenshot(
            id: "team-id-page",
            resourceName: "apple-developer-team-id",
            subdirectory: "AppleAccountGuide",
            caption: "Team ID is shown in Apple Developer membership details."
        )
    ]
}
