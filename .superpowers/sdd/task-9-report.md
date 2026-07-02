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
