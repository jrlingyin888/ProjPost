import XCTest
@testable import ProjPostCore

final class AppUpdateCheckerTests: XCTestCase {
    func testSemanticVersionComparesNumericComponents() throws {
        let current = try XCTUnwrap(AppVersion("1.9.9"))
        let latest = try XCTUnwrap(AppVersion("v1.10.0"))

        XCTAssertTrue(latest > current)
    }

    func testGitHubReleaseJSONDecodesLatestReleaseAndZipAsset() throws {
        let json = """
        {
          "tag_name": "v1.1.0",
          "name": "JJPost v1.1.0",
          "html_url": "https://github.com/jrlingyin888/ProjPost/releases/tag/v1.1.0",
          "assets": [
            {
              "name": "JJPost-1.1.0-dev-id.zip",
              "browser_download_url": "https://github.com/jrlingyin888/ProjPost/releases/download/v1.1.0/JJPost-1.1.0-dev-id.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        let release = try GitHubReleaseFetcher.decodeReleaseInfo(from: json)

        XCTAssertEqual(release.version, "1.1.0")
        XCTAssertEqual(release.tagName, "v1.1.0")
        XCTAssertEqual(release.name, "JJPost v1.1.0")
        XCTAssertEqual(release.releaseURL.absoluteString, "https://github.com/jrlingyin888/ProjPost/releases/tag/v1.1.0")
        XCTAssertEqual(release.assetDownloadURL?.absoluteString, "https://github.com/jrlingyin888/ProjPost/releases/download/v1.1.0/JJPost-1.1.0-dev-id.zip")
    }

    func testCheckerReportsAvailableWhenLatestReleaseIsNewer() async throws {
        let release = AppReleaseInfo(
            version: "1.1.0",
            tagName: "v1.1.0",
            name: "JJPost v1.1.0",
            releaseURL: URL(string: "https://github.com/jrlingyin888/ProjPost/releases/tag/v1.1.0")!,
            assetDownloadURL: nil
        )
        let checker = AppUpdateChecker(currentVersion: "1.0.0", fetcher: FakeReleaseInfoFetcher(release: release))

        let result = try await checker.checkForUpdate()

        XCTAssertEqual(result, .available(currentVersion: "1.0.0", latestRelease: release))
    }

    func testCheckerReportsUpToDateWhenLatestReleaseIsSameVersion() async throws {
        let release = AppReleaseInfo(
            version: "1.1.0",
            tagName: "v1.1.0",
            name: "JJPost v1.1.0",
            releaseURL: URL(string: "https://github.com/jrlingyin888/ProjPost/releases/tag/v1.1.0")!,
            assetDownloadURL: nil
        )
        let checker = AppUpdateChecker(currentVersion: "1.1.0", fetcher: FakeReleaseInfoFetcher(release: release))

        let result = try await checker.checkForUpdate()

        XCTAssertEqual(result, .upToDate(currentVersion: "1.1.0", latestVersion: "1.1.0"))
    }
}

private struct FakeReleaseInfoFetcher: AppReleaseInfoFetching {
    var release: AppReleaseInfo

    func fetchLatestRelease() async throws -> AppReleaseInfo {
        release
    }
}
