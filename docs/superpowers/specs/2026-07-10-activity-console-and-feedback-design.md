# Activity Console & Immediate Feedback Design

## Goal

Make JJPost's action feedback impossible to miss. Today, results of an action (upload, TestFlight refresh, beta submit, App Store review, group linking, release) land either in a per-section status line or in the `Upload Console`, which is the last item in a long scrolling detail pane — so it scrolls out of view. A user clicks a button at the top, the result appears far below, and the app feels unresponsive. This redesign adds a persistent, always-visible **activity console** at the bottom of the detail pane that logs every action, plus **immediate feedback** (an error banner and a success toast) so a click is acknowledged the instant it resolves.

## Scope

**In:**
- A unified in-memory **activity log** in Core: every action appends a timestamped, leveled entry.
- A **bottom-docked console pane** in the detail view: always visible, collapsible, auto-scrolls to the newest line, with a clear button. It replaces the scrolled-away `UploadProgressView`.
- **Immediate feedback**: an error banner (prominent, dismissible, persists until dismissed/replaced) and a success toast (auto-dismisses ~2s), both driven from the same log helper.
- **Auto-load no longer locks the whole UI**: the TestFlight status auto-load becomes a background read that logs to the console and shows an inline spinner without flipping the global operation lock.
- **Cleanup**: remove the now-dead auto-link-after-approval code (model fields, view-model setters, the `autoAfterApproval` string, and their tests).

**Out:**
- No change to what the actions themselves do (upload/submit/refresh/link/release logic is unchanged).
- No persistence of the activity log across app launches (in-memory only).
- No change to the two-column `NavigationSplitView` shell; the console docks inside the existing detail pane.

## Global Constraints

- No new third-party dependencies.
- Every new user-facing string is added to `AppStrings` in both English and Simplified Chinese via `text("English", "简体中文")`.
- All new logic lives in **ProjPostCore** with tests; the App target stays a thin rendering layer.
- `AppViewModel` is not `@MainActor`; log/notice mutations happen at the same points where the existing published state is mutated, matching sibling methods (no new `MainActor.run` beyond the existing pattern).

## Component 1 — Activity log (Core)

New types in `DomainModels.swift`:

```
enum ActivityLevel { case info, success, error }

struct ActivityEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: ActivityLevel
    let message: String
}

struct Notice: Identifiable, Equatable {   // drives the transient banner/toast
    let id: UUID
    let level: ActivityLevel               // .success or .error only
    let message: String
}
```

On `AppViewModel`:
- `@Published public private(set) var activityLog: [ActivityEntry]` (newest appended last; capped at a max length, e.g. 200, dropping oldest).
- `@Published public var notice: Notice?` (settable so the view can clear it on dismiss/toast-timeout).
- A single private helper:

```
func recordActivity(_ level: ActivityLevel, _ message: String) {
    activityLog.append(ActivityEntry(id: UUID(), timestamp: Date(), level: level, message: message))
    if activityLog.count > 200 { activityLog.removeFirst(activityLog.count - 200) }
    if level == .success || level == .error {
        notice = Notice(id: UUID(), level: level, message: message)
    }
}
public func clearActivityLog() { activityLog.removeAll() }
public func dismissNotice() { notice = nil }
```

Every action calls `recordActivity` at its key points — at minimum a `.info` "started" line and a `.success`/`.error` result line, reusing the exact user-facing message the action already computes (e.g. `strings.uploadFailed(error)`). Upload pipeline events (`checkBundleAndApp` + the runner's `UploadEvent`s) each append an entry (`.success`/`.error` by `event.succeeded`), so the console shows the full upload trace. The existing per-section published states (`uploadState`, `betaReviewState`, `appStoreReviewState`, `testFlightDistributionState`) remain unchanged — the log is additive, not a replacement.

## Component 2 — Bottom-docked console (UI)

`ProjectDetailView.body` changes from `ScrollView { VStack { …, UploadProgressView } }` to:

```
VStack(spacing: 0) {
    ScrollView { VStack { header … appStoreReviewActions } }   // UploadProgressView removed here
    ConsolePane(entries: viewModel.activityLog, isCollapsed: $consoleCollapsed, onClear: viewModel.clearActivityLog)
}
```

`ConsolePane` (new view, `Views/ConsolePane.swift`):
- A header row: a terminal icon + `strings.activityConsole` title, a spacer, a clear button (`strings.clear`), and a collapse/expand chevron bound to a `@State private var consoleCollapsed` in the detail view.
- When expanded: a fixed-height (~180pt), independently scrolling list of entries, each rendered as `HH:mm:ss` (monospaced, secondary) + a level glyph/color (info = gray dot, success = green check, error = red x) + the message (monospaced). A `ScrollViewReader` scrolls to the newest entry's id whenever `entries.count` changes.
- When collapsed: only the header row shows (plus the newest entry's message as a one-line summary).
- Empty state: `strings.noActivityYet`.
- The old `UploadProgressView.swift` is removed (its content is now the unified log).

## Component 3 — Immediate feedback (UI)

Driven by `viewModel.notice`, rendered as an overlay at the top of the detail pane (above the ScrollView, inside the outer `VStack`, as an `.overlay(alignment: .top)` or a top-anchored element):

- **Error** (`level == .error`): a red, rounded banner with the message and a close (X) button. It stays until the user dismisses it (`viewModel.dismissNotice()`) or it is replaced by a newer notice. Prominent — this is the "popup on error" the user asked for.
- **Success** (`level == .success`): a green, rounded toast with the message. A `.task(id: notice?.id)` starts a ~2s sleep, then calls `dismissNotice()` if that notice is still current. Auto-dismissing.
- Only one notice is shown at a time (the newest). Info-level entries never raise a notice (console only).

## Component 4 — Auto-load without locking the UI

The TestFlight status auto-load (wired via `.task(id: latestBuildStatusTrigger)` → `refreshLatestBuildTestFlightStatusIfNeeded`) must not disable the rest of the UI while it reads. Approach:
- Add `@Published public private(set) var isBackgroundLoadingTestFlight: Bool`. `refreshLatestBuildTestFlightStatusIfNeeded` (the automatic on-entry path) routes to a **non-locking background load**: it sets `isBackgroundLoadingTestFlight = true`, does the read-only `loadLatestBuildDistribution`, then sets `testFlightDistributionState = .loaded(snapshot)` (or `.failed`) and `isBackgroundLoadingTestFlight = false`. Crucially it does **not** set `testFlightDistributionState = .loading` (the state that feeds `isOperationRunning`), so `isOperationRunning` stays `false` and unrelated controls remain clickable. It logs `recordActivity(.info, …)` on start and `.success`/`.error` on completion.
- The explicit "Refresh TF Status" button keeps calling `refreshLatestBuildTestFlightStatus` unchanged (it is a deliberate user action; leaving its existing `.loading`-based lock is acceptable) — only the automatic on-entry load is de-coupled from the global lock. During a background load, a small inline spinner in the TestFlight section keys off `isBackgroundLoadingTestFlight`; the section keeps showing the previous snapshot until the new one arrives.

## Component 5 — Remove dead auto-link code

The auto-link-after-approval feature was retired when refresh became read-only. Remove its now-dead remnants:
- `ProjectProfile.autoLinkExternalGroupsAfterBetaApproval` and `.autoLinkExternalGroupIDsAfterBetaApproval` (Codable decode of older JSON that still contains these keys stays safe — unknown keys are ignored).
- `AppViewModel.updateAutoLinkExternalGroupsAfterBetaApproval(_:)` and `updateAutoLinkExternalGroup(_:isEnabled:)`, and the `upsertProject` copies of those fields.
- `AppStrings.autoAfterApproval`.
- Tests asserting those fields/setters (update or remove).

## Testing

Core tests (ProjPostCore):
- `recordActivity` appends an entry and caps the log at 200; `.info` does not set `notice`; `.success`/`.error` set a `notice` of the matching level.
- A failing action (e.g. `startUpload` with a blocked config, or `refreshLatestBuildTestFlightStatus` on a fake that throws) appends an `.error` entry and sets an `.error` notice; a succeeding action appends a `.success` entry.
- Upload events each produce a log entry with the level matching `event.succeeded`.
- Background TestFlight auto-load does not set `isOperationRunning` while running, and logs start/finish entries.
- `clearActivityLog` empties the log; `dismissNotice` clears the notice.
- Removal regression: building compiles with the auto-link fields/setters/string gone.

The console pane, error banner, and success toast are view-layer and verified by `swift build` (no warnings) plus launching the packaged dev `.app` and driving an action (e.g. a deliberately-failing "Upload to TestFlight") to confirm the console logs it and the error banner appears without scrolling.
