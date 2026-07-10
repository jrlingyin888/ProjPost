# App Store Review Advanced Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let JJPost save App Store version localization fields and App Review information, refresh the main review section after saving, and display existing App Store screenshots read from App Store Connect.

**Architecture:** Extend the App Store Connect client with focused update/read methods, keep writable review/localization state in `AppViewModel`, and keep screenshot upload out of scope for this slice. The SwiftUI advanced sheet edits a local draft, calls a save closure, then closes only after the ViewModel updates the remote data and refreshes the snapshot.

**Tech Stack:** Swift 5.9, SwiftUI on macOS 13+, XCTest, App Store Connect API JSON:API.

## Global Constraints

- Do not add new third-party dependencies.
- Preserve the existing App Store review flow: refresh/create version, choose build, bind build, submit review.
- Screenshot upload/replacement is not included; existing screenshots are read-only in this slice.
- Demo passwords are editable but hidden by default in the UI.
- Existing dirty worktree changes are user/work-in-progress changes and must not be reverted.

---

### Task 1: Client Update And Screenshot Read APIs

**Files:**
- Modify: `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`
- Test: `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`

**Interfaces:**
- Produces:
  - `ASCAppStoreVersionLocalizationUpdate`
  - `ASCAppStoreReviewDetailUpdate`
  - `ASCAppScreenshotSet`
  - `ASCAppScreenshot`
  - `updateAppStoreVersionLocalization(localizationID:update:)`
  - `updateAppStoreReviewDetail(reviewDetailID:update:)`
  - `fetchAppScreenshotSets(appStoreVersionLocalizationID:)`
  - `fetchAppScreenshots(appScreenshotSetID:)`

- [ ] Write failing tests for the four new client methods.
- [ ] Run targeted client tests and confirm the new tests fail before implementation.
- [ ] Add the minimal models, protocol methods, JSON request bodies, and response mappers.
- [ ] Run targeted client tests and confirm they pass.

### Task 2: Snapshot And ViewModel Save Flow

**Files:**
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`
- Test: `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`

**Interfaces:**
- Consumes Task 1 client methods.
- Produces:
  - `AppStoreReviewLocalizationScreenshotSet`
  - `AppStoreReviewAdvancedDraft`
  - `saveAppStoreReviewAdvancedDraft(_:)`

- [ ] Write failing ViewModel tests showing save updates localizations/review detail and refreshes screenshot data.
- [ ] Run targeted ViewModel tests and confirm failure.
- [ ] Extend snapshots with screenshot sets and add a ViewModel save method.
- [ ] Update fake clients to satisfy the expanded protocol.
- [ ] Run targeted ViewModel tests and confirm they pass.

### Task 3: Advanced Sheet UI

**Files:**
- Modify: `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift`

**Interfaces:**
- Consumes `AppStoreReviewAdvancedDraft` and `saveAppStoreReviewAdvancedDraft(_:)`.
- Produces a sheet with Cancel/Save buttons, hidden-by-default password editing, cleaner review-info sections, and read-only existing screenshot groups.

- [ ] Replace the local-only sheet state with a draft initialized from the current snapshot.
- [ ] Add Cancel and Save actions.
- [ ] Render screenshot sets from the refreshed snapshot rather than only local file selections.
- [ ] Keep chosen local screenshots visually separate as a future-upload draft area.
- [ ] Run the full test suite.
- [ ] Rebuild and reopen the preview app.
