# Apple Guide and JJPost Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Apple Account setup guide sheet, rename the delivered app to `JJPost`, and package a single-`J` tech-style macOS icon.

**Architecture:** Keep product-facing text and guide content in small core value types so tests can verify behavior without UI automation. SwiftUI consumes those value types and bundled image resources. The package script remains the final product delivery path and copies executable resources plus `AppIcon.icns` into `dist/JJPost.app`.

**Tech Stack:** Swift 5.9, SwiftUI macOS, SwiftPM resources, XCTest, Python/Pillow for deterministic icon raster generation, `iconutil` for `.icns`.

## Global Constraints

- Delivered app bundle name: `dist/JJPost.app`.
- Visible app name: `JJPost`.
- Keep executable target name `ProjPostApp`.
- Keep existing storage directory `ProjPost` and Keychain service `com.projpost.appstoreconnect`.
- Icon uses one capital `J`, not `JJ`, with dimensional tech styling.
- Apple Account guide is static/local and includes the two provided screenshots.
- `.p8` import behavior and Keychain storage are unchanged.
- No signing, notarization, DMG, repository rename, or module rename.

---

### Task 1: Core Branding and Guide Content

**Files:**
- Create: `Sources/ProjPostCore/Branding/ProductBranding.swift`
- Create: `Sources/ProjPostCore/Guides/AppleAccountGuideContent.swift`
- Create: `Tests/ProjPostCoreTests/ProductBrandingTests.swift`
- Create: `Tests/ProjPostCoreTests/AppleAccountGuideContentTests.swift`

**Interfaces:**
- Produces: `ProductBranding.displayName: String`, `ProductBranding.bundleIdentifier: String`, `ProductBranding.iconFileName: String`
- Produces: `AppleAccountGuideContent.sections: [AppleAccountGuideSection]`, `AppleAccountGuideContent.screenshots: [AppleAccountGuideScreenshot]`, and reference URLs.

- [ ] **Step 1: Write failing branding tests**

```swift
import XCTest
@testable import ProjPostCore

final class ProductBrandingTests: XCTestCase {
    func testVisibleBrandingUsesJJPostWhilePreservingLegacyStorageNames() {
        XCTAssertEqual(ProductBranding.displayName, "JJPost")
        XCTAssertEqual(ProductBranding.bundleIdentifier, "com.jjpost.app")
        XCTAssertEqual(ProductBranding.iconFileName, "AppIcon")
        XCTAssertEqual(ProductBranding.legacyApplicationSupportDirectoryName, "ProjPost")
        XCTAssertEqual(ProductBranding.legacyKeychainService, "com.projpost.appstoreconnect")
    }
}
```

- [ ] **Step 2: Write failing guide content tests**

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
swift test --filter 'ProductBrandingTests|AppleAccountGuideContentTests'
```

Expected: FAIL because `ProductBranding` and `AppleAccountGuideContent` are not defined.

- [ ] **Step 4: Implement branding and guide content**

```swift
import Foundation

public enum ProductBranding {
    public static let displayName = "JJPost"
    public static let bundleIdentifier = "com.jjpost.app"
    public static let iconFileName = "AppIcon"
    public static let legacyApplicationSupportDirectoryName = "ProjPost"
    public static let legacyKeychainService = "com.projpost.appstoreconnect"
}
```

```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter 'ProductBrandingTests|AppleAccountGuideContentTests'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/Branding/ProductBranding.swift Sources/ProjPostCore/Guides/AppleAccountGuideContent.swift Tests/ProjPostCoreTests/ProductBrandingTests.swift Tests/ProjPostCoreTests/AppleAccountGuideContentTests.swift
git commit -m "feat: add JJPost branding and Apple guide content"
```

### Task 2: Apple Account Guide Sheet and Resources

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- Create: `Sources/ProjPostApp/Views/AppleAccountGuideView.swift`
- Create: `Sources/ProjPostApp/Resources/AppleAccountGuide/app-store-connect-api-key.png`
- Create: `Sources/ProjPostApp/Resources/AppleAccountGuide/apple-developer-team-id.png`

**Interfaces:**
- Consumes: `AppleAccountGuideContent.sections`, `.screenshots`, `.appStoreConnectURL`, `.developerMembershipURL`.
- Produces: a `Guide` button beside the Apple Account label and a local sheet with text, links, and screenshots.

- [ ] **Step 1: Copy the provided screenshots into app resources**

Run:

```bash
mkdir -p Sources/ProjPostApp/Resources/AppleAccountGuide
cp /var/folders/38/qhzslwjj3gl0x3mlbgy2f9qm0000gn/T/codex-clipboard-4995d7de-468f-4a11-8685-82a181ced1fa.png Sources/ProjPostApp/Resources/AppleAccountGuide/app-store-connect-api-key.png
cp /var/folders/38/qhzslwjj3gl0x3mlbgy2f9qm0000gn/T/codex-clipboard-815fe39a-333f-4c2b-bc6c-3a82f7cf04f9.png Sources/ProjPostApp/Resources/AppleAccountGuide/apple-developer-team-id.png
```

Expected: both files exist under `Sources/ProjPostApp/Resources/AppleAccountGuide/`.

- [ ] **Step 2: Update SwiftPM resources**

Modify `Package.swift` so `ProjPostApp` has:

```swift
.executableTarget(
    name: "ProjPostApp",
    dependencies: ["ProjPostCore"],
    resources: [
        .process("Resources")
    ]
),
```

- [ ] **Step 3: Add the guide SwiftUI view**

Create `Sources/ProjPostApp/Views/AppleAccountGuideView.swift` with:

```swift
import AppKit
import ProjPostCore
import SwiftUI

struct AppleAccountGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    linkRow
                    ForEach(AppleAccountGuideContent.sections) { section in
                        guideSection(section)
                    }
                    ForEach(AppleAccountGuideContent.screenshots) { screenshot in
                        guideScreenshot(screenshot)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 620, idealHeight: 720)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Account Guide")
                    .font(.title2.weight(.semibold))
                Text("Find the .p8 key, Key ID, Issuer ID, and Team ID for JJPost.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var linkRow: some View {
        HStack(spacing: 12) {
            Link("Open App Store Connect API", destination: AppleAccountGuideContent.appStoreConnectURL)
            Link("Open Apple Developer Account", destination: AppleAccountGuideContent.developerMembershipURL)
            Spacer()
        }
        .buttonStyle(.bordered)
    }

    private func guideSection(_ section: AppleAccountGuideSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
            ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    Text(step)
                        .font(.callout)
                }
            }
        }
    }

    private func guideScreenshot(_ screenshot: AppleAccountGuideScreenshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(screenshot.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let image = loadImage(screenshot) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.quaternary)
                    )
            } else {
                Label("Screenshot resource missing: \(screenshot.resourceName)", systemImage: "photo")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func loadImage(_ screenshot: AppleAccountGuideScreenshot) -> NSImage? {
        guard let url = Bundle.module.url(
            forResource: screenshot.resourceName,
            withExtension: "png",
            subdirectory: screenshot.subdirectory
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
```

- [ ] **Step 4: Wire the guide button into Apple Account**

In `ProjectDetailView`, add:

```swift
@State private var showAppleAccountGuide = false
```

Add this modifier to the root view:

```swift
.sheet(isPresented: $showAppleAccountGuide) {
    AppleAccountGuideView()
}
```

Replace the Apple Account label with:

```swift
HStack(spacing: 8) {
    Label("Apple Account", systemImage: "person.crop.square")
    Button {
        showAppleAccountGuide = true
    } label: {
        Label("Guide", systemImage: "questionmark.circle")
    }
    .buttonStyle(.borderless)
    .help("How to find .p8, Key ID, Issuer ID, and Team ID")
}
```

- [ ] **Step 5: Build to verify resources compile**

Run:

```bash
swift build
```

Expected: build succeeds and `AppleAccountGuideView` can access `Bundle.module`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/ProjPostApp/Views/ProjectDetailView.swift Sources/ProjPostApp/Views/AppleAccountGuideView.swift Sources/ProjPostApp/Resources/AppleAccountGuide/app-store-connect-api-key.png Sources/ProjPostApp/Resources/AppleAccountGuide/apple-developer-team-id.png
git commit -m "feat: add Apple account guide sheet"
```

### Task 3: JJPost App Naming and Icon Packaging

**Files:**
- Modify: `Sources/ProjPostApp/ProjPostApp.swift`
- Modify: `Sources/ProjPostApp/Views/ContentView.swift`
- Modify: `scripts/package_app.sh`
- Create: `Sources/ProjPostApp/Resources/AppIcon.iconset/`
- Create: `Sources/ProjPostApp/Resources/AppIcon.icns`

**Interfaces:**
- Consumes: `ProductBranding.displayName`, `.bundleIdentifier`, `.iconFileName`.
- Produces: `dist/JJPost.app` with `AppIcon.icns`.

- [ ] **Step 1: Generate deterministic single-J icon assets**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import subprocess

root = Path("Sources/ProjPostApp/Resources")
root.mkdir(parents=True, exist_ok=True)
base_png = root / "AppIcon-1024.png"
iconset = root / "AppIcon.iconset"
iconset.mkdir(parents=True, exist_ok=True)

size = 1024
corner = 220
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
pixels = bg.load()
for y in range(size):
    for x in range(size):
        nx = x / (size - 1)
        ny = y / (size - 1)
        radial = max(0, 1 - math.sqrt((nx - 0.38) ** 2 + (ny - 0.22) ** 2) * 1.25)
        r = int(9 + 18 * radial + 10 * ny)
        g = int(28 + 80 * radial + 18 * nx)
        b = int(60 + 150 * radial + 60 * (1 - ny))
        pixels[x, y] = (r, g, b, 255)

mask = Image.new("L", (size, size), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=corner, fill=255)
img.alpha_composite(bg)
img.putalpha(mask)

draw = ImageDraw.Draw(img)
for i in range(8):
    inset = 44 + i * 10
    alpha = max(15, 95 - i * 10)
    draw.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=corner - 42,
        outline=(80, 230, 255, alpha),
        width=2
    )

grid = Image.new("RGBA", (size, size), (0, 0, 0, 0))
gdraw = ImageDraw.Draw(grid)
for x in range(-size, size * 2, 78):
    gdraw.line([(x, 0), (x + size // 2, size)], fill=(75, 220, 255, 24), width=2)
for y in range(120, size, 92):
    gdraw.line([(80, y), (size - 80, y + 24)], fill=(75, 220, 255, 20), width=2)
grid.putalpha(Image.composite(grid.getchannel("A"), Image.new("L", (size, size), 0), mask))
img.alpha_composite(grid)

font_paths = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Avenir Next Condensed.ttc",
    "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf",
]
font_path = next((p for p in font_paths if Path(p).exists()), None)
if not font_path:
    raise SystemExit("No usable system font found for icon generation")
font = ImageFont.truetype(font_path, 720)

text = "J"
bbox = draw.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
x = (size - tw) // 2 - bbox[0] + 18
y = (size - th) // 2 - bbox[1] - 6

shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
sdraw = ImageDraw.Draw(shadow)
for offset in range(52, 0, -4):
    sdraw.text((x + offset, y + offset), text, font=font, fill=(0, 20, 50, 9))
shadow = shadow.filter(ImageFilter.GaussianBlur(10))
img.alpha_composite(shadow)

glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
gdraw = ImageDraw.Draw(glow)
for radius, alpha in [(28, 52), (16, 70), (8, 92)]:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(layer)
    ldraw.text((x, y), text, font=font, fill=(62, 224, 255, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(radius))
    glow.alpha_composite(layer)
img.alpha_composite(glow)

for offset, color in [
    (30, (12, 75, 130, 230)),
    (20, (18, 105, 170, 235)),
    (11, (28, 150, 210, 240)),
]:
    draw.text((x + offset, y + offset), text, font=font, fill=color)
draw.text((x, y), text, font=font, fill=(202, 250, 255, 255))
draw.text((x - 10, y - 10), text, font=font, fill=(255, 255, 255, 80))

highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
hdraw = ImageDraw.Draw(highlight)
hdraw.ellipse([120, 70, 760, 430], fill=(255, 255, 255, 38))
highlight = highlight.filter(ImageFilter.GaussianBlur(34))
highlight.putalpha(Image.composite(highlight.getchannel("A"), Image.new("L", (size, size), 0), mask))
img.alpha_composite(highlight)

img.save(base_png)

sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for name, px in sizes:
    img.resize((px, px), Image.Resampling.LANCZOS).save(iconset / name)

subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(root / "AppIcon.icns")], check=True)
PY
```

Expected: `Sources/ProjPostApp/Resources/AppIcon.icns` exists.

- [ ] **Step 2: Use JJPost in SwiftUI**

Update `ProjPostApp.swift`:

```swift
import ProjPostCore
import SwiftUI

@main
struct ProjPostApp: App {
    var body: some Scene {
        WindowGroup(ProductBranding.displayName) {
            ContentView()
                .frame(minWidth: 1120, minHeight: 720)
        }
    }
}
```

Update `ContentView.swift` to add:

```swift
.navigationTitle(ProductBranding.displayName)
```

- [ ] **Step 3: Update package script**

Update `scripts/package_app.sh` to:

- Set `APP_NAME="JJPost"`.
- Keep `EXECUTABLE_NAME="ProjPostApp"`.
- Create `Contents/Resources`.
- Copy SwiftPM resource bundles into `Contents/Resources`.
- Copy `Sources/ProjPostApp/Resources/AppIcon.icns` to `Contents/Resources/AppIcon.icns`.
- Set `CFBundleIdentifier` to `com.jjpost.app`.
- Set `CFBundleName` and `CFBundleDisplayName` to `JJPost`.
- Set `CFBundleIconFile` to `AppIcon`.

- [ ] **Step 4: Package and inspect**

Run:

```bash
scripts/package_app.sh
plutil -p dist/JJPost.app/Contents/Info.plist
test -f dist/JJPost.app/Contents/Resources/AppIcon.icns
```

Expected: package succeeds, Info.plist shows `JJPost`, and icon file exists.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostApp/ProjPostApp.swift Sources/ProjPostApp/Views/ContentView.swift scripts/package_app.sh Sources/ProjPostApp/Resources/AppIcon.icns
git commit -m "feat: package app as JJPost"
```

### Task 4: Final Verification and Relaunch

**Files:**
- Modify: none unless verification reveals a defect.

**Interfaces:**
- Consumes: completed Tasks 1-3.
- Produces: verified `dist/JJPost.app`.

- [ ] **Step 1: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Run full build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 3: Package product app**

Run:

```bash
scripts/package_app.sh
```

Expected: `dist/JJPost.app` is generated.

- [ ] **Step 4: Relaunch packaged app**

Run:

```bash
osascript -e 'tell application id "com.jjpost.app" to quit' || true
open dist/JJPost.app
```

Expected: app opens as `JJPost` with the new icon.

- [ ] **Step 5: Commit any verification fixes**

If verification required a code fix, commit only the related files. For example, if the package script needed a resource-copy correction, run:

```bash
git add scripts/package_app.sh
git commit -m "fix: polish JJPost packaging"
```
