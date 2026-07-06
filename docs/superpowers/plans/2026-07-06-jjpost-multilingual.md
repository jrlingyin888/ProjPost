# JJPost Multilingual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement JJPost v1.1.0 multilingual support with English as default and Simplified Chinese selectable from the lower-left app panel.

**Architecture:** Add a typed localization layer in `ProjPostCore`, wire a persisted `LocalizationStore` into SwiftUI, and move visible UI/status strings through `AppStrings`. Core workflow messages are generated from the current `AppLanguage`; raw external command/API output remains untranslated.

**Tech Stack:** Swift, SwiftUI, Combine, UserDefaults, XCTest.

## Global Constraints

- Default language is English.
- Supported languages are English and Simplified Chinese.
- Language picker lives in the lower-left Add Project panel next to version text.
- Language choice persists locally and applies immediately.
- Raw command output and old persisted historical messages are not translated.

---

### Task 1: Core Localization Layer

**Files:**
- Create: `Sources/ProjPostCore/Localization/AppLanguage.swift`
- Create: `Sources/ProjPostCore/Localization/AppStrings.swift`
- Create: `Sources/ProjPostCore/Localization/LocalizationStore.swift`
- Test: `Tests/ProjPostCoreTests/LocalizationTests.swift`

**Interfaces:**
- Produces: `AppLanguage`, `AppStrings`, `LocalizationStore`.
- Consumes: `UserDefaults`.

- [x] Write tests for default language, persistence, language display names, and representative English/Chinese strings.
- [x] Verify tests fail before the new localization files exist.
- [x] Implement `AppLanguage`, `AppStrings`, and `LocalizationStore`.
- [x] Verify localization tests pass.

### Task 2: View Wiring and Sidebar Picker

**Files:**
- Modify: `Sources/ProjPostApp/Views/ContentView.swift`
- Modify: `Sources/ProjPostApp/Views/ProjectListView.swift`
- Modify: `Sources/ProjPostApp/Views/UploadProgressView.swift`
- Modify: `Sources/ProjPostApp/Views/AppleAccountGuideView.swift`
- Test: `Tests/ProjPostCoreTests/LocalizationTests.swift`

**Interfaces:**
- Consumes: `LocalizationStore` from the SwiftUI environment.
- Produces: immediate UI language switching.

- [x] Add tests for sidebar/account/upload strings used by views.
- [x] Replace hard-coded view strings with `AppStrings`.
- [x] Add the language picker next to `ProductBranding.appVersionDisplay`.
- [x] Make Apple Account Guide default to the global language while preserving its segmented picker.
- [x] Verify tests pass.

### Task 3: Core Status and Check Messages

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Modify: `Sources/ProjPostCore/Checks/ConfigurationCheckEngine.swift`
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`
- Test: `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`
- Test: `Tests/ProjPostCoreTests/DomainModelsTests.swift`

**Interfaces:**
- Consumes: `AppLanguage`.
- Produces: localized status labels, failures, upload summaries, beta review statuses, and configuration check labels.

- [x] Add/update tests for English default status labels and Simplified Chinese variants.
- [x] Add `language` support to `AppViewModel` and `ConfigurationCheckEngine`.
- [x] Localize core user-facing messages while preserving raw external output.
- [x] Verify focused tests pass.

### Task 4: Verification and Packaging

**Files:**
- Modify only if verification exposes issues.

**Interfaces:**
- Consumes: current Developer ID certificate and release scripts.
- Produces: a runnable JJPost app on the feature branch.

- [x] Run `swift test`.
- [x] Run `APP_VERSION=1.1.0 scripts/package_app.sh`.
- [x] Run `codesign --verify --deep --strict --verbose=2 dist/JJPost.app`.
- [x] Run `open -n dist/JJPost.app` for manual inspection.
