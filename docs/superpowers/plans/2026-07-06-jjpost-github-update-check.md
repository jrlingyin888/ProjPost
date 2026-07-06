# JJPost GitHub Update Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add scheme A update checking: detect newer GitHub Releases and open the release page for manual download/install.

**Architecture:** Add a small core update checker that parses GitHub latest release JSON and compares semantic versions. Wire it into `AppViewModel` as injectable state, then present a localized SwiftUI alert from `ContentView`.

**Tech Stack:** Swift, SwiftUI, URLSession, Codable, XCTest.

## Global Constraints

- Use GitHub Releases for `jrlingyin888/ProjPost`.
- Only alert and open the release page; do not auto-download or replace the app.
- Default language remains English with Simplified Chinese supported.
- Network failures must not block launch.

---

### Task 1: Core Update Checker

**Files:**
- Create: `Sources/ProjPostCore/Updates/AppUpdateChecker.swift`
- Test: `Tests/ProjPostCoreTests/AppUpdateCheckerTests.swift`

**Interfaces:**
- Produces: `AppVersion`, `AppReleaseInfo`, `AppUpdateCheckResult`, `AppReleaseInfoFetching`, `GitHubReleaseFetcher`, `AppUpdateChecker`.

- [x] Write failing tests for semantic version comparison, release JSON decoding, newer release detection, and same-version no-update detection.
- [x] Run `swift test --filter AppUpdateCheckerTests` and confirm failure because update types do not exist.
- [x] Implement the core update checker and parser.
- [x] Run `swift test --filter AppUpdateCheckerTests` and confirm pass.

### Task 2: ViewModel State

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes: `AppUpdateChecking`.
- Produces: `@Published updateState`, `checkForUpdatesIfNeeded()`, `dismissAvailableUpdate()`.

- [x] Write failing ViewModel tests for available update, no update, and silent failure.
- [x] Run focused ViewModel tests and confirm failure.
- [x] Implement injectable update checker state in `AppViewModel`.
- [x] Run focused ViewModel tests and confirm pass.

### Task 3: Localized Alert UI

**Files:**
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift`
- Modify: `Tests/ProjPostCoreTests/LocalizationTests.swift`
- Modify: `Sources/ProjPostApp/Views/ContentView.swift`

**Interfaces:**
- Consumes: `viewModel.availableUpdate`.
- Produces: localized launch-time update alert with Download Update and Later buttons.

- [x] Add localized string tests for the update alert.
- [x] Add update strings to `AppStrings`.
- [x] Wire `ContentView` to call `checkForUpdatesIfNeeded()` and present the alert.
- [x] Run `swift test`.

### Task 4: Package and Launch

**Files:**
- No source changes unless verification exposes an issue.

- [x] Run `git diff --check`.
- [x] Run `APP_VERSION=1.1.0 scripts/package_app.sh`.
- [x] Run `codesign --verify --deep --strict --verbose=2 dist/JJPost.app`.
- [x] Restart `dist/JJPost.app`.
