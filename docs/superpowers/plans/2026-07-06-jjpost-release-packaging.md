# JJPost Release Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add repeatable release scripts that let JJPost produce both a quick Developer ID-signed test zip and a notarized distribution zip.

**Architecture:** Keep the SwiftPM app packaging flow, but split release concerns into focused shell scripts. `package_app.sh` builds and signs the app, `select_signing_identity.sh` chooses the best certificate for the configured team, `release_zip.sh` produces the downloadable zip, and `notarize_app.sh` submits/staples the app when credentials are available.

**Tech Stack:** SwiftPM, Bash, `codesign`, `ditto`, `xcrun notarytool`, `xcrun stapler`, XCTest process tests.

## Global Constraints

- App name remains `JJPost`.
- Default app version remains `1.0.0`.
- Default team ID is `T46A6Q874U`.
- Quick internal distribution may be Developer ID-signed but unnotarized.
- Formal GitHub Releases distribution should be Developer ID-signed, notarized, stapled, and zipped.

---

### Task 1: Deterministic Signing Identity Selection

**Files:**
- Create: `scripts/select_signing_identity.sh`
- Modify: `scripts/package_app.sh`
- Test: `Tests/ProjPostCoreTests/ReleaseScriptsTests.swift`

**Interfaces:**
- Consumes: `APPLE_TEAM_ID`, `SIGN_IDENTITY`, `CODESIGN_IDENTITY`, optional `SECURITY_FIND_IDENTITY_OUTPUT`.
- Produces: a single signing identity string on stdout, preferring Developer ID Application for the configured team.

- [ ] Write failing XCTest that runs `scripts/select_signing_identity.sh` with mocked `security find-identity` output and expects `Developer ID Application: Yating Wang (T46A6Q874U)`.
- [ ] Run the focused XCTest and confirm it fails because the script does not exist.
- [ ] Implement `select_signing_identity.sh` and update `package_app.sh` to call it.
- [ ] Run the focused XCTest and confirm it passes.

### Task 2: Release Zip Script

**Files:**
- Create: `scripts/release_zip.sh`
- Test: `Tests/ProjPostCoreTests/ReleaseScriptsTests.swift`

**Interfaces:**
- Consumes: `APP_VERSION`, `APP_NAME`, `DIST_DIR`, `APP_DIR`, `RELEASE_KIND`, `BUILD_IF_MISSING`.
- Produces: `dist/JJPost-<version>-<release-kind>.zip`.

- [ ] Write failing XCTest that creates a fake `JJPost.app`, runs `scripts/release_zip.sh` with `BUILD_IF_MISSING=0`, and expects `JJPost-1.0.0-dev-id.zip`.
- [ ] Run the focused XCTest and confirm it fails because the script does not exist.
- [ ] Implement `release_zip.sh`.
- [ ] Run the focused XCTest and confirm it passes.

### Task 3: Optional Notarization Script

**Files:**
- Create: `scripts/notarize_app.sh`
- Test: `Tests/ProjPostCoreTests/ReleaseScriptsTests.swift`

**Interfaces:**
- Consumes: `NOTARYTOOL_PROFILE` or `APPLE_ID` + `APP_SPECIFIC_PASSWORD` + `APPLE_TEAM_ID`; `DRY_RUN=1` prints the intended commands without uploading.
- Produces: a notarized and stapled app when credentials are valid; exits clearly when credentials are missing.

- [ ] Write failing XCTest that runs `scripts/notarize_app.sh` with `DRY_RUN=1` and a fake app path and expects the notarytool/stapler command preview.
- [ ] Run the focused XCTest and confirm it fails because the script does not exist.
- [ ] Implement `notarize_app.sh`.
- [ ] Run the focused XCTest and confirm it passes.

### Task 4: Verification

**Files:**
- Modify: release scripts only if verification exposes script issues.

**Interfaces:**
- Consumes: current installed Developer ID certificate.
- Produces: signed app, unnotarized quick zip, clear notarization status.

- [ ] Run `swift test`.
- [ ] Run `APP_VERSION=1.0.0 scripts/package_app.sh`.
- [ ] Run `codesign --verify --deep --strict --verbose=2 dist/JJPost.app`.
- [ ] Run `codesign -dv --verbose=4 dist/JJPost.app` and confirm `Developer ID Application: Yating Wang (T46A6Q874U)`.
- [ ] Run `scripts/release_zip.sh` and confirm the quick internal zip exists.
- [ ] Run `spctl --assess --type execute -vv dist/JJPost.app` and record whether the current build is unnotarized or accepted.
