### Task 7: Project Backup and Mutation

- Added `Sources/ProjPostCore/Project/ProjectMutator.swift` with:
  - `ProjectMutationRequest`
  - `ProjectMutationChange`
  - `ProjectMutationPlan`
  - `ProjectMutatorError`
  - `ProjectMutator.plan(request:)`
  - `ProjectMutator.apply(_:)`
- Added `Tests/ProjPostCoreTests/ProjectMutatorTests.swift` with:
  - `testPlanIncludesBackupAndReadableSummary`
  - `RecordingFileSystem` test double

### TDD evidence
- Ran `swift test --filter ProjectMutatorTests` before implementation.
  - Failed as expected because `ProjectMutator` and `ProjectMutationRequest` did not exist yet.
- Implemented the new mutator and plan types.
- Ran `swift test --filter ProjectMutatorTests` again.
  - Passed: 1 test, 0 failures.
- Ran `swift test` full suite.
  - Passed: 25 tests, 0 failures.

### Behavior delivered
- Plans only when the project `.pbxproj` exists.
- Collects readable change summaries for bundle ID, version, and build number edits.
- Includes the `.pbxproj` and present `Info.plist` in the backup set.
- Uses a dated backup folder under the configured backup root.
- Writes backups before mutating the project file.
- Replaces the expected project setting strings conservatively in the `.pbxproj`.

### Commit
- `feat: plan and backup project mutations`

### Notes
- No unrelated files were modified.
- The implementation stays within the brief’s conservative scope and does not attempt to support unsupported project shapes.

### Review Fix Report
- Fixed the ProjectMutator interface gap by adding a public bridge from `ProjectProfile`:
  - `ProjectMutator.request(from:targetBundleID:targetVersion:targetBuildNumber:infoPlistURL:)`
  - `ProjectMutator.plan(project:targetBundleID:targetVersion:targetBuildNumber:infoPlistURL:)`
- The bridge now derives:
  - `projectRoot` from `ProjectProfile.projectPath`
  - `pbxprojURL` from `ProjectProfile.projectFilePath` when present, otherwise the project name fallback
  - current bundle/version/build values from `ProjectProfile`
  - target bundle/version/build values from the bridge arguments
- Made backup directories collision-resistant by appending a UUID suffix to the timestamped folder name.
- Updated tests to cover:
  - planning from a `ProjectProfile` with summaries and backup files asserted
  - two back-to-back plans producing distinct backup directories

### Tests Run
- `swift test --filter ProjectMutatorTests`
  - Passed: 2 tests, 0 failures
- `swift test`
  - Passed: 26 tests, 0 failures

### Files Changed
- `Sources/ProjPostCore/Project/ProjectMutator.swift`
- `Tests/ProjPostCoreTests/ProjectMutatorTests.swift`

### Commit Created
- `feat: plan and backup project mutations`

### Review Fix Report
- Fixed `ProjectMutator.apply(_:)` so each requested replacement now verifies that the expected old setting text exists before writing the `.pbxproj`.
- Added `ProjectMutatorError.expectedSettingNotFound(String)` and made bundle ID, version, and build number substitutions throw when the old setting string is missing.
- Added a regression test that feeds a Bundle ID change plan with `.pbxproj` text missing `PRODUCT_BUNDLE_IDENTIFIER = com.old.demo;`, then verifies `apply(_:)` throws and does not write the mutated project file.

### Tests Run
- `swift test --filter ProjectMutatorTests`
  - Passed: 3 tests, 0 failures
- `swift test`
  - Passed: 27 tests, 0 failures

### Files Changed
- `Sources/ProjPostCore/Project/ProjectMutator.swift`
- `Tests/ProjPostCoreTests/ProjectMutatorTests.swift`

### Commit Created
- `feat: guard project mutation replacements`

### Notes
- `ProjectMutatorError.noChanges` behavior was left unchanged because the task brief explicitly mandates it as an error for no-change requests.

### Review Fix Report
- Fixed the planning path so a requested mutation now fails fast when the current project value is missing instead of producing an unapplyable change.
- Added `ProjectMutatorError.missingCurrentValue(String)` and made `appendChange` throw for `nil` current values whenever a target value is present.
- Added a regression test that uses a `ProjectProfile` with `version == nil` and `targetVersion` set, then verifies planning throws `missingCurrentValue("Version")`.

### Tests Run
- `swift test --filter ProjectMutatorTests`
  - Passed: 4 tests, 0 failures
- `swift test`
  - Passed: 28 tests, 0 failures

### Files Changed
- `Sources/ProjPostCore/Project/ProjectMutator.swift`
- `Tests/ProjPostCoreTests/ProjectMutatorTests.swift`
- `.superpowers/sdd/task-7-report.md`

### Commit Created
- `2d1756e` (`fix: reject project mutation plans without current values`)

### Finalized Review Fix Report
- What fixed: `ProjectMutator.plan(request:)` now fails fast when a change is requested but the corresponding current value is `nil`, by throwing `ProjectMutatorError.missingCurrentValue(<label>)` from `appendChange`.
- Tests run and outputs:
  - `swift test --filter ProjectMutatorTests`: Passed, 4 tests, 0 failures.
  - `swift test`: Passed, 28 tests, 0 failures.
- Files changed:
  - `Sources/ProjPostCore/Project/ProjectMutator.swift`
  - `Tests/ProjPostCoreTests/ProjectMutatorTests.swift`
  - `.superpowers/sdd/task-7-report.md`
- Commit created:
  - `2d1756e` (`fix: reject project mutation plans without current values`)
