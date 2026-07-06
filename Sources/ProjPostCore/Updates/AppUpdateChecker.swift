import Foundation

public struct AppVersion: Comparable, Equatable {
    private let components: [Int]

    public init?(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? ""

        let parsed = normalized.split(separator: ".").map { Int($0) }
        guard !parsed.isEmpty, parsed.allSatisfy({ $0 != nil }) else { return nil }
        self.components = parsed.map { $0 ?? 0 }
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = lhs.components.indices.contains(index) ? lhs.components[index] : 0
            let right = rhs.components.indices.contains(index) ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

public struct AppReleaseInfo: Equatable {
    public var version: String
    public var tagName: String
    public var name: String
    public var releaseURL: URL
    public var assetDownloadURL: URL?

    public init(version: String, tagName: String, name: String, releaseURL: URL, assetDownloadURL: URL?) {
        self.version = version
        self.tagName = tagName
        self.name = name
        self.releaseURL = releaseURL
        self.assetDownloadURL = assetDownloadURL
    }
}

public enum AppUpdateCheckResult: Equatable {
    case available(currentVersion: String, latestRelease: AppReleaseInfo)
    case upToDate(currentVersion: String, latestVersion: String)
}

public protocol AppReleaseInfoFetching {
    func fetchLatestRelease() async throws -> AppReleaseInfo
}

public protocol AppUpdateChecking {
    func checkForUpdate() async throws -> AppUpdateCheckResult
}

public enum AppUpdateState: Equatable {
    case idle
    case checking
    case available(currentVersion: String, latestRelease: AppReleaseInfo)
}

public struct GitHubReleaseFetcher: AppReleaseInfoFetching {
    private let latestReleaseURL: URL
    private let session: URLSession

    public init(
        owner: String = "jrlingyin888",
        repository: String = "ProjPost",
        session: URLSession = .shared
    ) {
        self.latestReleaseURL = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        self.session = session
    }

    public func fetchLatestRelease() async throws -> AppReleaseInfo {
        let (data, response) = try await session.data(from: latestReleaseURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.badStatus(httpResponse.statusCode)
        }
        return try Self.decodeReleaseInfo(from: data)
    }

    public static func decodeReleaseInfo(from data: Data) throws -> AppReleaseInfo {
        let response = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        let version = response.tagName.normalizedReleaseVersion
        guard let releaseURL = URL(string: response.htmlURL) else {
            throw AppUpdateError.invalidReleaseURL
        }
        let assetURL = response.assets
            .first(where: { $0.name.lowercased().hasSuffix(".zip") })
            .flatMap { URL(string: $0.browserDownloadURL) }
        return AppReleaseInfo(
            version: version,
            tagName: response.tagName,
            name: response.name,
            releaseURL: releaseURL,
            assetDownloadURL: assetURL
        )
    }
}

public struct AppUpdateChecker {
    private let currentVersion: String
    private let fetcher: AppReleaseInfoFetching

    public init(currentVersion: String = ProductBranding.appVersion, fetcher: AppReleaseInfoFetching = GitHubReleaseFetcher()) {
        self.currentVersion = currentVersion
        self.fetcher = fetcher
    }

    public func checkForUpdate() async throws -> AppUpdateCheckResult {
        let release = try await fetcher.fetchLatestRelease()
        guard let current = AppVersion(currentVersion),
              let latest = AppVersion(release.version),
              latest > current else {
            return .upToDate(currentVersion: currentVersion, latestVersion: release.version)
        }
        return .available(currentVersion: currentVersion, latestRelease: release)
    }
}

extension AppUpdateChecker: AppUpdateChecking {}

public enum AppUpdateError: Error, Equatable {
    case badStatus(Int)
    case invalidReleaseURL
}

private struct GitHubReleaseResponse: Decodable {
    var tagName: String
    var name: String
    var htmlURL: String
    var assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    var name: String
    var browserDownloadURL: String

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private extension String {
    var normalizedReleaseVersion: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")
    }

    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
