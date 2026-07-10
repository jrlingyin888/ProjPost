# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native macOS SwiftUI app (SwiftPM, macOS 13+) that automates shipping an **iOS** app to TestFlight / the App Store. It scans an Xcode project, validates configuration against App Store Connect, archives/exports/uploads the build, then drives TestFlight beta review, external-group linking, and App Store review submission — all from a local Mac, using an App Store Connect API key (`.p8`).

The internal/package name is **ProjPost**; the user-facing product is **JJPost**. Both names are load-bearing and appear throughout (targets, bundle names, Keychain service, `dist/` artifacts). Do not "unify" them.

## Commands

```bash
swift build                        # build everything
swift run ProjPostApp              # run the app during development (no .app bundle needed)
swift test                         # run the full test suite
swift test --filter ProjPostCoreTests.AppViewModelStateTests            # one test class
swift test --filter ProjPostCoreTests.AppViewModelStateTests/testFoo    # one test method
```

Release / distribution (see `docs/jjpost-update-release-flow.md` for the full flow):

```bash
APP_VERSION=1.1.0 scripts/package_app.sh                       # build & assemble dist/JJPost.app
APP_VERSION=1.1.0 BUILD_IF_MISSING=0 scripts/release_zip.sh    # zip -> dist/JJPost-<ver>-dev-id.zip
scripts/notarize_app.sh                                        # notarytool submit + staple (needs creds)
```

The `scripts/*.sh` are covered by `ReleaseScriptsTests` — they're driven with injected env vars (e.g. `SECURITY_FIND_IDENTITY_OUTPUT`) so they can be unit-tested without touching the real Keychain or network. Preserve that seam when editing them.

## Architecture

Two targets plus one test target:
- **ProjPostCore** — all logic lives here (library, fully unit-tested).
- **ProjPostApp** — a thin SwiftUI shell (`@main`, Views/). Keep behavior in Core, not in Views.
- **ProjPostCoreTests** — tests target Core exclusively.

### Everything hangs off `AppViewModel`
[`AppViewModel`](Sources/ProjPostCore/AppState/AppViewModel.swift) is the single `ObservableObject` the UI binds to. It owns all published state (projects, accounts, check results, upload/beta/review states, language) and orchestrates every workflow. It is the file to read first and the file most changes touch.

Its collaborators are injected as **protocols declared at the top of `AppViewModel.swift`** (`ProjectProfileStoreProtocol`, `ProjectScanning`, `ConfigurationCheckEngineProtocol`, `UploadJobRunning`, `ProjectMutating`, plus `AppStoreConnectClientProtocol` and `AppUpdateChecking`). Concrete types conform via one-line `extension` declarations. This indirection is what makes Core testable — tests pass fakes into `AppViewModel.init`. When adding a dependency, follow the same pattern: protocol + default concrete instance in `init`.

Two conventions to respect in `AppViewModel`:
- Every mutating/action method early-returns on `guard !isOperationRunning`. New actions must do the same to avoid concurrent operations corrupting state.
- Async work that mutates published state hops back through `await MainActor.run { … }` (the class itself is **not** `@MainActor` — a known, accepted tech-debt).

### External processes go through `CommandRunning`
All shell-outs (`xcodebuild`, `rsync`, etc.) run via [`CommandRunning`/`ProcessCommandRunner`](Sources/ProjPostCore/Support/CommandRunner.swift), never `Process` directly. `ProcessCommandRunner` normalizes `PATH` (adds Homebrew paths). Tests inject fake runners returning canned `CommandResult`s. Any new external tool invocation must use this abstraction.

### The upload pipeline
`startUpload` → config checks → `UploadJobRunner`: build the `xcodebuild archive` command via `UploadCommandBuilder`, export the IPA using an `ExportOptionsPlistWriter`-generated plist, locate the exported `.ipa`, then upload. The `.p8` key is read from Keychain and written to a **per-run temp dir with `0600` perms**, then deleted in a `defer`. Never let the private key reach JSON, UI, or logs.

### Configuration checks (red / yellow / green)
[`ConfigurationCheckEngine`](Sources/ProjPostCore/Checks/ConfigurationCheckEngine.swift) validates Xcode env, Bundle ID existence, app match, Team ID, and build number against App Store Connect. **Red blocks upload; yellow requires explicit user confirmation; green passes.** Checks are context-keyed (`CheckContext`) and invalidated whenever project/account/key state changes.

### App Store Connect
[`AppStoreConnectClient`](Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift) wraps the ASC REST API; requests are authorized with an ES256 JWT minted by `AppStoreConnectJWTSigner` (swift-crypto). Domain structs are prefixed `ASC*`. `ProjectMutator` edits the `.xcodeproj` via the **XcodeProj** library (not string replacement — it backs up the project first, under Application Support).

### Persistence & credentials
- Project/account metadata → JSON in the user's **Application Support** directory (`ProjectProfileStore`, `AppleAccountProfileStore`).
- The `.p8` private key → **macOS Keychain only**, via `CredentialVault` (`KeychainCredentialVault`, service `com.projpost.appstoreconnect`), keyed by account UUID.

### Localization is hand-rolled — not String Catalogs
There is **no `.xcstrings`**. All user-facing text is a computed property on [`AppStrings`](Sources/ProjPostCore/Localization/AppStrings.swift) using `text("English", "简体中文")`, switched on `AppLanguage` (`.english` / `.simplifiedChinese`). **Every new user-facing string must be added to `AppStrings` with both languages** — passing English text directly to a View will not localize.

### Branding & the update flow
[`ProductBranding`](Sources/ProjPostCore/Branding/ProductBranding.swift) is the single source of truth for display name, `bundleIdentifier`, and `appVersion`. `AppUpdateChecker` hits the GitHub Releases API (`jrlingyin888/ProjPost`) and compares the latest tag against `ProductBranding.appVersion` to prompt an update. Releasing a new version = bump `appVersion` there, then run the packaging/release scripts and `gh release create`. Updates are download-and-replace (manual), not auto-installing.

## Conventions & gotchas

- Do **not** commit real `.p8` contents, Key IDs, or Issuer IDs. `dist/`, `.build/`, `.worktrees/`, and `.superpowers/` are gitignored.
- New logic belongs in **ProjPostCore** with tests; the App target should stay a thin SwiftUI layer.
- `swift run ProjPostApp` is the fast dev loop — you don't need to package a `.app` to try changes.
- Design specs and handoff notes live in `docs/` and `docs/superpowers/` (specs, plans, manual test checklist, update/release flow). Check there before large changes.
