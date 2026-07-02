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
