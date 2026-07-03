import XCTest
@testable import ProjPostCore

final class ProductBrandingTests: XCTestCase {
    func testVisibleBrandingUsesJJPostWhilePreservingLegacyStorageNames() {
        XCTAssertEqual(ProductBranding.displayName, "JJPost")
        XCTAssertEqual(ProductBranding.appVersion, "1.0.0")
        XCTAssertEqual(ProductBranding.appVersionDisplay, "v1.0.0")
        XCTAssertEqual(ProductBranding.bundleIdentifier, "com.jjpost.app")
        XCTAssertEqual(ProductBranding.iconFileName, "AppIcon")
        XCTAssertEqual(ProductBranding.legacyApplicationSupportDirectoryName, "ProjPost")
        XCTAssertEqual(ProductBranding.legacyKeychainService, "com.projpost.appstoreconnect")
    }
}
