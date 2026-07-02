# Task 3 Report (2026-07-02)

## Implemented
- Added `Sources/ProjPostCore/Project/ProjectScanner.swift` with:
  - `ProjectScanResult` model + `toProjectProfile(nameOverride:)`
  - `ProjectScanner` implementation that:
    - scans `.xcworkspace` and `.xcodeproj` entries via `FileSysteming.contentsOfDirectory(_:)`
    - runs `xcodebuild -list -json`
    - picks scheme list and first scheme as selected
    - runs `xcodebuild -showBuildSettings -json -scheme <selected>`
    - maps bundle id/version/build number/team id from `buildSettings`
  - `ProjectScannerError.commandFailed`
- Added `Tests/ProjPostCoreTests/ProjectScannerTests.swift` with:
  - fake command runner
  - fake scanner filesystem
  - case: `testScannerReadsWorkspaceSchemeAndBuildSettings`

## Validation
- TDD red/green flow:
  - `swift test --filter ProjectScannerTests` with scanner source temporarily removed:
    - FAIL (`cannot find 'ProjectScanner' in scope`)
  - `swift test --filter ProjectScannerTests` after implementation:
    - PASS (1 test, 0 failures)
- Full suite:
  - `swift test`
  - PASS (5 tests, 0 failures)

## Commit
- `ac6f9c6` — `feat: scan Xcode project settings`

## Review Fix Addendum

### What I fixed
- Updated `ProjectScanner` to prefer the build settings entry whose `target` matches the selected scheme.
- Kept the fallback order requested by review: first non-empty `PRODUCT_BUNDLE_IDENTIFIER`, then the first entry.
- Added `ProjectScannerError.missingXcodeProject(URL)` and now fail before invoking `xcodebuild` when neither `.xcworkspace` nor `.xcodeproj` is present.
- Added regression coverage for:
  - matching app target vs. leading test target
  - missing project selector path with no command execution

### Tests run and outputs
- `swift test --filter ProjectScannerTests`
  - Passed: 3 tests, 0 failures
- `swift test`
  - Passed: 7 tests, 0 failures

### Files changed
- `/Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost/.worktrees/ios-uploader-mvp/Sources/ProjPostCore/Project/ProjectScanner.swift`
- `/Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost/.worktrees/ios-uploader-mvp/Tests/ProjPostCoreTests/ProjectScannerTests.swift`
- `/Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost/.worktrees/ios-uploader-mvp/.superpowers/sdd/task-3-report.md`

### Commit created
- `fix: harden project scanner selection`
