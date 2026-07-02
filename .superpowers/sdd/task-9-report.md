# Task 9 Report

## Files Changed

- `Sources/ProjPostCore/AppState/AppViewModel.swift`
- `Sources/ProjPostApp/Views/ContentView.swift`
- `Sources/ProjPostApp/Views/ProjectListView.swift`
- `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- `Sources/ProjPostApp/Views/CheckResultsView.swift`
- `Sources/ProjPostApp/Views/UploadProgressView.swift`
- `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

## Behavior Implemented

- Added a testable `AppViewModel` in `ProjPostCore` with injected seams for project storage, scanning, configuration checks, and uploads.
- Exposed app state for projects, selected project, editable project fields, Apple account draft/profile state, check results, upload state, and upload events.
- Implemented project loading, saving, selection, creation, field updates, and scanner-driven project refresh/add flow.
- Implemented configuration check orchestration with clear blocked states for:
  - no selected project
  - no Apple account
  - red check results
- Implemented upload orchestration with required yellow-warning confirmation via `startUpload(confirmedYellowIssues:)`.
- Captured upload events and updated the selected project’s `lastUpload` summary on success or failure.
- Built the macOS SwiftUI shell:
  - left project list and add panel
  - right-side editable project workbench
  - Apple account metadata section
  - configuration check panel
  - TestFlight/upload controls
  - upload console/log panel
- Used `swift build` for verification instead of leaving `swift run ProjPostApp` running, since this environment is not suitable for keeping a GUI process attached for handoff.

## Tests Run

1. `swift test --filter AppViewModelStateTests`
   - Result: PASS
   - Executed 11 tests, 0 failures

2. `swift test`
   - Result: PASS
   - Executed 45 tests, 0 failures

3. `swift build`
   - Result: PASS
   - Build complete

## Concerns

- The new UI captures Apple account metadata, but this task did not add a `.p8` import/save flow into `CredentialVault`. Live checks/uploads from a fresh session still depend on a matching key already existing in the vault.

## Task 9 Fix Report

### Findings Fixed

- Gated uploads on configuration checks that match the current selected project/account/private-key snapshot, so empty or stale `checkResults` no longer allow upload attempts.
- Invalidated checks and upload readiness on project edits, account draft edits, account selection changes, account saves, and `.p8` imports while preserving yellow-confirmation behavior for current checks.
- Added `AppleAccountProfileStore` JSON persistence for non-secret Apple account metadata and hydrated per-project selected accounts on load/select without overwriting `selectedAccountID` during ordinary project edits.
- Injected `CredentialVault` into `AppViewModel`, added `importPrivateKey(from:)` / `importPrivateKeyPEM(_:)`, and wired a real macOS `.p8` file importer that stores raw key material only in Keychain while surfacing saved/missing/failed status.
- Reworked the left pane into selectable project cards, cleared both add-project draft fields after add, and added internal/public TestFlight placeholder rows in the upload section.
- Added regression coverage for missing/stale checks, selected-account persistence, vault-backed `.p8` import, and the new account profile store.

### Files Changed

- `Sources/ProjPostCore/AppState/AppViewModel.swift`
- `Sources/ProjPostCore/Storage/AppleAccountProfileStore.swift`
- `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- `Sources/ProjPostApp/Views/ProjectListView.swift`
- `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`
- `Tests/ProjPostCoreTests/AppleAccountProfileStoreTests.swift`

### Verification

1. `swift test --filter AppViewModelStateTests`
   - Result: PASS
   - Executed 16 tests, 0 failures

2. `swift test --filter AppleAccountProfileStoreTests`
   - Result: PASS
   - Executed 2 tests, 0 failures

3. `swift test`
   - Result: PASS
   - Executed 52 tests, 0 failures

4. `swift build`
   - Result: PASS
   - Build complete

### Concerns

- None.
