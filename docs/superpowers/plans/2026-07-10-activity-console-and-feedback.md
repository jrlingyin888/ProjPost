# Activity Console & Immediate Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every action instant, always-visible feedback: a bottom-docked activity console that logs all actions, plus an error banner and success toast.

**Architecture:** A unified in-memory activity log lives on `AppViewModel`, fed by one `recordActivity` helper. Logging is wired via `didSet` observers on the four published state enums (`uploadState`, `uploadEvents`, `betaReviewState`, `appStoreReviewState`) so every terminal transition — including guard-rejected clicks — logs automatically, DRY, with no per-method edits. A new `ConsolePane` docks at the bottom of the detail view; a top overlay renders the newest notice as an error banner (persistent) or success toast (auto-dismiss).

**Tech Stack:** Swift 5.9, SwiftUI on macOS 13+, Combine `@Published`, XCTest.

## Global Constraints

- No new third-party dependencies.
- Every new user-facing string is added to `AppStrings` in both English and Simplified Chinese via `text("English", "简体中文")`.
- All new logic lives in **ProjPostCore** with tests; the App target stays a thin rendering layer.
- `AppViewModel` is not `@MainActor`; new mutations follow the existing sibling pattern (no new `MainActor.run`).
- The activity log is in-memory only (not persisted) and capped at 200 entries (drop oldest).
- `@Published` `didSet` observers fire even for assignments made inside `init`; therefore `activityLog`/`notice` MUST be declared with default initializers (`= []` / `= nil`) so they exist before any state `didSet` runs, and the init-time state values (`.idle`, `[]`) MUST map to no log entry.

## File Structure

- `Sources/ProjPostCore/Models/DomainModels.swift` — add `ActivityLevel`, `ActivityEntry`, `ActivityNotice`.
- `Sources/ProjPostCore/AppState/AppViewModel.swift` — add `activityLog`/`notice` state, `recordActivity`/`clearActivityLog`/`dismissNotice`, `didSet` logging on four state vars, the non-locking background TestFlight load, and removal of dead auto-link code.
- `Sources/ProjPostCore/Localization/AppStrings.swift` — new strings (both languages).
- `Sources/ProjPostApp/Views/ConsolePane.swift` — new docked console view.
- `Sources/ProjPostApp/Views/ProjectDetailView.swift` — dock the console, add the notice overlay, add the background-load spinner, remove the old `UploadProgressView` usage.
- `Sources/ProjPostApp/Views/UploadProgressView.swift` — deleted (content folded into the unified console).
- Tests: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`, `Tests/ProjPostCoreTests/DomainModelsTests.swift`.

---

### Task 1: Activity log primitives (Core)

**Files:**
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Produces: `ActivityLevel { info, success, error }`; `ActivityEntry { id: UUID, timestamp: Date, level: ActivityLevel, message: String }`; `ActivityNotice { id: UUID, level: ActivityLevel, message: String }`; on `AppViewModel`: `@Published public private(set) var activityLog: [ActivityEntry]`, `@Published public var notice: ActivityNotice?`, `func recordActivity(_ level: ActivityLevel, _ message: String)` (internal), `func clearActivityLog()`, `func dismissNotice()`.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`:

```swift
func testRecordActivityAppendsAndRaisesNoticeOnlyForSuccessError() {
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner()
    )
    viewModel.recordActivity(.info, "loading")
    XCTAssertEqual(viewModel.activityLog.map(\.message), ["loading"])
    XCTAssertNil(viewModel.notice)

    viewModel.recordActivity(.error, "boom")
    XCTAssertEqual(viewModel.activityLog.last?.level, .error)
    XCTAssertEqual(viewModel.notice?.level, .error)
    XCTAssertEqual(viewModel.notice?.message, "boom")

    viewModel.recordActivity(.success, "done")
    XCTAssertEqual(viewModel.notice?.level, .success)
}

func testActivityLogCapsAtTwoHundred() {
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner()
    )
    for i in 0..<205 { viewModel.recordActivity(.info, "m\(i)") }
    XCTAssertEqual(viewModel.activityLog.count, 200)
    XCTAssertEqual(viewModel.activityLog.first?.message, "m5")
    XCTAssertEqual(viewModel.activityLog.last?.message, "m204")
}

func testClearLogAndDismissNotice() {
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner()
    )
    viewModel.recordActivity(.error, "x")
    viewModel.clearActivityLog()
    viewModel.dismissNotice()
    XCTAssertTrue(viewModel.activityLog.isEmpty)
    XCTAssertNil(viewModel.notice)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testRecordActivityAppendsAndRaisesNoticeOnlyForSuccessError`
Expected: FAIL — `value of type 'AppViewModel' has no member 'recordActivity'`.

- [ ] **Step 3: Add the model types**

In `Sources/ProjPostCore/Models/DomainModels.swift`, append:

```swift
public enum ActivityLevel: Equatable {
    case info
    case success
    case error
}

public struct ActivityEntry: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let level: ActivityLevel
    public let message: String

    public init(id: UUID = UUID(), timestamp: Date, level: ActivityLevel, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct ActivityNotice: Identifiable, Equatable {
    public let id: UUID
    public let level: ActivityLevel
    public let message: String

    public init(id: UUID = UUID(), level: ActivityLevel, message: String) {
        self.id = id
        self.level = level
        self.message = message
    }
}
```

- [ ] **Step 4: Add the state and helpers to `AppViewModel`**

In `Sources/ProjPostCore/AppState/AppViewModel.swift`, add these two published properties next to the other `@Published` declarations (they MUST have default initializers so they exist before any `didSet` fires):

```swift
    @Published public private(set) var activityLog: [ActivityEntry] = []
    @Published public var notice: ActivityNotice?
```

Add these methods (place them near the other small helpers, e.g. after `dismissAvailableUpdate()`):

```swift
    func recordActivity(_ level: ActivityLevel, _ message: String) {
        activityLog.append(ActivityEntry(timestamp: Date(), level: level, message: message))
        if activityLog.count > 200 {
            activityLog.removeFirst(activityLog.count - 200)
        }
        if level == .success || level == .error {
            notice = ActivityNotice(level: level, message: message)
        }
    }

    public func clearActivityLog() {
        activityLog.removeAll()
    }

    public func dismissNotice() {
        notice = nil
    }
```

- [ ] **Step 5: Run to verify pass**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testRecordActivityAppendsAndRaisesNoticeOnlyForSuccessError` then the two sibling tests.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/Models/DomainModels.swift Sources/ProjPostCore/AppState/AppViewModel.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat(core): add activity log + notice primitives"
```

---

### Task 2: Wire logging via didSet on state enums (Core)

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes Task 1's `recordActivity`.
- Produces: `didSet` logging on `uploadState`, `uploadEvents`, `betaReviewState`, `appStoreReviewState`; a new string `appStoreReviewStatusRefreshed`.

- [ ] **Step 1: Write the failing tests**

Append to `AppViewModelStateTests.swift`:

```swift
func testBlockedUploadLogsErrorAndRaisesErrorNotice() async {
    // No project selected → startUpload hits a guard and sets uploadState = .failed,
    // which must surface as an error log entry + error notice (the "click does nothing" case).
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner()
    )

    await viewModel.startUpload()

    XCTAssertEqual(viewModel.activityLog.last?.level, .error)
    XCTAssertEqual(viewModel.notice?.level, .error)
}

func testUploadEventsAppendToActivityLog() {
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner()
    )

    viewModel.uploadEvents = [
        UploadEvent(step: .archive, message: "Archived", succeeded: true),
        UploadEvent(step: .upload, message: "Upload failed", succeeded: false)
    ]

    XCTAssertEqual(viewModel.activityLog.count, 2)
    XCTAssertEqual(viewModel.activityLog.first?.level, .success)
    XCTAssertEqual(viewModel.activityLog.last?.level, .error)
    XCTAssertTrue(viewModel.activityLog.last?.message.contains("Upload failed") == true)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testBlockedUploadLogsErrorAndRaisesErrorNotice`
Expected: FAIL — `activityLog.last` is nil (no didSet logging yet).

- [ ] **Step 3: Add the new string**

In `AppStrings.swift`, near the other App Store review strings:

```swift
    public var appStoreReviewStatusRefreshed: String { text("Store review info updated", "商店审核信息已更新") }
```

- [ ] **Step 4: Add didSet observers + mappers**

In `AppViewModel.swift`, add `didSet` clauses to these four existing `@Published` declarations (keep their types unchanged):

```swift
    @Published public var uploadState: UploadJobState { didSet { logUploadStateChange(uploadState) } }
    @Published public var uploadEvents: [UploadEvent] { didSet { logNewUploadEvents(since: oldValue) } }
    @Published public var betaReviewState: BetaReviewSubmissionState { didSet { logBetaReviewStateChange(betaReviewState) } }
    @Published public var appStoreReviewState: AppStoreReviewState { didSet { logAppStoreReviewStateChange(appStoreReviewState) } }
```

Add the mapper methods (near `recordActivity`):

```swift
    private func logUploadStateChange(_ state: UploadJobState) {
        switch state {
        case .succeeded(let message): recordActivity(.success, message)
        case .failed(let message): recordActivity(.error, message)
        case .cancelled: recordActivity(.info, strings.cancelled)
        case .idle, .running: break   // progress detail comes from uploadEvents
        }
    }

    private func logNewUploadEvents(since oldValue: [UploadEvent]) {
        guard uploadEvents.count > oldValue.count else { return }
        for event in uploadEvents[oldValue.count...] {
            recordActivity(event.succeeded ? .success : .error, "\(strings.uploadStep(event.step)): \(event.message)")
        }
    }

    private func logBetaReviewStateChange(_ state: BetaReviewSubmissionState) {
        switch state {
        case .succeeded(let message): recordActivity(.success, message)
        case .failed(let message): recordActivity(.error, message)
        default: break
        }
    }

    private func logAppStoreReviewStateChange(_ state: AppStoreReviewState) {
        switch state {
        case .succeeded(let message, _): recordActivity(.success, message)
        case .failed(let message, _): recordActivity(.error, message)
        case .loaded: recordActivity(.info, strings.appStoreReviewStatusRefreshed)
        default: break
        }
    }
```

> Note: the init-time assignments (`uploadState = .idle`, `uploadEvents = []`, `betaReviewState = .idle`, `appStoreReviewState = .idle`) all map to no log entry, so no spurious startup logs. `activityLog`/`notice` have default initializers (Task 1) and so are safe to touch when these `didSet`s fire during init.

- [ ] **Step 5: Run to verify pass**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests`
Expected: PASS (both new tests green; all prior green).

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Sources/ProjPostCore/Localization/AppStrings.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat(core): log all action outcomes via state didSet observers"
```

---

### Task 3: Non-locking background TestFlight auto-load (Core)

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes Task 1 `recordActivity`, existing `loadLatestBuildDistribution`, `testFlightDistributionErrorMessage`.
- Produces: `@Published public private(set) var isBackgroundLoadingTestFlight: Bool`; `refreshLatestBuildTestFlightStatusIfNeeded()` rerouted to a non-locking background load.

- [ ] **Step 1: Write the failing test**

Append to `AppViewModelStateTests.swift`:

```swift
func testBackgroundAutoLoadDoesNotLockUIAndLogs() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED")],
        betaGroups: []
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )

    await viewModel.refreshLatestBuildTestFlightStatusIfNeeded()

    // Background load must NOT flip the global operation lock, and must not touch betaReviewState (the manual-refresh channel).
    XCTAssertFalse(viewModel.isOperationRunning)
    XCTAssertFalse(viewModel.isBackgroundLoadingTestFlight)
    if case .loaded = viewModel.testFlightDistributionState {} else { XCTFail("expected loaded snapshot") }
    if case .idle = viewModel.betaReviewState {} else { XCTFail("background load must not set betaReviewState") }
    // It logged the read (info level → console, no success toast on entry).
    XCTAssertEqual(viewModel.activityLog.last?.level, .info)
    XCTAssertNil(viewModel.notice)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testBackgroundAutoLoadDoesNotLockUIAndLogs`
Expected: FAIL — `no member 'isBackgroundLoadingTestFlight'` (and the current `IfNeeded` calls the locking path).

- [ ] **Step 3: Add the background-load state and reroute `IfNeeded`**

In `AppViewModel.swift`, add the published flag next to the others:

```swift
    @Published public private(set) var isBackgroundLoadingTestFlight = false
```

Replace the existing `refreshLatestBuildTestFlightStatusIfNeeded()` with:

```swift
    public func refreshLatestBuildTestFlightStatusIfNeeded() async {
        guard latestBuildStatusTrigger != "not-ready" else { return }
        guard !isOperationRunning else { return }
        guard !isBackgroundLoadingTestFlight else { return }
        await loadTestFlightStatusInBackground()
    }

    private func loadTestFlightStatusInBackground() async {
        guard let project = selectedProject, let account = accountProfile else { return }
        isBackgroundLoadingTestFlight = true
        defer { isBackgroundLoadingTestFlight = false }
        do {
            let loaded = try await loadLatestBuildDistribution(project: project, account: account)
            testFlightDistributionState = .loaded(loaded.snapshot)
            recordActivity(.info, strings.testFlightStatus(loaded.snapshot.betaReviewStateText))
        } catch {
            let message = testFlightDistributionErrorMessage(error)
            testFlightDistributionState = .failed(message: message)
            recordActivity(.error, message)
        }
    }
```

> This never sets `testFlightDistributionState = .loading` (the state that feeds `isOperationRunning`) and never touches `betaReviewState`, so the rest of the UI stays interactive. `.loaded` on `testFlightDistributionState` has no `didSet`, so the explicit `recordActivity` here is the only log for a background load — success as `.info` (console only, no toast on entry), failure as `.error` (toast).

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testBackgroundAutoLoadDoesNotLockUIAndLogs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat(core): non-locking background TestFlight auto-load"
```

---

### Task 4: Remove dead auto-link code (Core)

**Files:**
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:** removes `ProjectProfile.autoLinkExternalGroupsAfterBetaApproval` / `.autoLinkExternalGroupIDsAfterBetaApproval`, `AppViewModel.updateAutoLinkExternalGroupsAfterBetaApproval(_:)` / `updateAutoLinkExternalGroup(_:isEnabled:)`, and `AppStrings.autoAfterApproval`.

- [ ] **Step 1: Remove the model fields**

In `DomainModels.swift`, delete these lines (all in `ProjectProfile`):
- The two stored properties (lines ~30-31): `public var autoLinkExternalGroupsAfterBetaApproval: Bool` and `public var autoLinkExternalGroupIDsAfterBetaApproval: Set<String>`.
- The two `init` parameters (lines ~48-49): `autoLinkExternalGroupsAfterBetaApproval: Bool = false,` and `autoLinkExternalGroupIDsAfterBetaApproval: Set<String> = []`.
- The two `init` assignments (lines ~69-70): `self.autoLinkExternalGroupsAfterBetaApproval = …` and `self.autoLinkExternalGroupIDsAfterBetaApproval = …`.
- The two `CodingKeys` cases (lines ~88-89).
- The two `decodeIfPresent` lines in `init(from:)` (lines ~112-113).
- The two `encode` lines in `encode(to:)` (lines ~132-133).

(Decoding older saved JSON that still contains these keys stays safe — `Decodable` ignores unknown keys.)

- [ ] **Step 2: Remove the view-model setters and upsert copies**

In `AppViewModel.swift`:
- Delete the whole `updateAutoLinkExternalGroupsAfterBetaApproval(_:)` method (lines ~506-513).
- Delete the whole `updateAutoLinkExternalGroup(_:isEnabled:)` method (lines ~515-525).
- In `upsertProject`, delete the two lines `updated.autoLinkExternalGroupsAfterBetaApproval = projects[index].autoLinkExternalGroupsAfterBetaApproval` (lines ~1130 and ~1137).

- [ ] **Step 3: Remove the string**

In `AppStrings.swift`, delete the `autoAfterApproval` property (line ~125).

- [ ] **Step 4: Update the tests that referenced the removed API**

In `AppViewModelStateTests.swift`:
- Delete the two assertions at lines ~64-65 (`XCTAssertFalse(project.autoLinkExternalGroupsAfterBetaApproval)` and `XCTAssertEqual(project.autoLinkExternalGroupIDsAfterBetaApproval, [])`).
- Delete the entire test that exercises `updateAutoLinkExternalGroup` (the one spanning lines ~141-152 — the calls at 145-147 and assertions at 149-151).
- Delete the line `project.autoLinkExternalGroupIDsAfterBetaApproval = ["external-a"]` (~line 454) inside `testRefreshTestFlightStatusIsReadOnlyEvenWhenAutoLinkConfigured` — the test still validates read-only refresh with a plain approved build; keep the rest.
- Delete the three redundant lines `project.autoLinkExternalGroupsAfterBetaApproval = false` (~lines 503, 543, 580) — that was the default anyway.

- [ ] **Step 5: Build and run the full suite**

Run: `swift build` then `swift test`
Expected: compiles with no reference to the removed symbols; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/Models/DomainModels.swift Sources/ProjPostCore/AppState/AppViewModel.swift Sources/ProjPostCore/Localization/AppStrings.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "chore(core): remove dead auto-link-after-approval code"
```

---

### Task 5: Docked console + notice banner/toast UI (App)

**Files:**
- Create: `Sources/ProjPostApp/Views/ConsolePane.swift`
- Modify: `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift`
- Delete: `Sources/ProjPostApp/Views/UploadProgressView.swift`

**Interfaces:** consumes `viewModel.activityLog`, `viewModel.notice`, `viewModel.clearActivityLog()`, `viewModel.dismissNotice()`, `viewModel.isBackgroundLoadingTestFlight`, and `ActivityEntry`/`ActivityLevel`/`ActivityNotice`.

- [ ] **Step 1: Add the UI strings (both languages)**

In `AppStrings.swift`, add near the other console strings:

```swift
    public var activityConsole: String { text("Activity Console", "活动控制台") }
    public var clearLog: String { text("Clear", "清空") }
    public var noActivityYet: String { text("No activity yet.", "暂无活动。") }
```

- [ ] **Step 2: Create `ConsolePane.swift`**

Create `Sources/ProjPostApp/Views/ConsolePane.swift`:

```swift
import ProjPostCore
import SwiftUI

struct ConsolePane: View {
    let entries: [ActivityEntry]
    @Binding var isCollapsed: Bool
    let onClear: () -> Void
    @EnvironmentObject private var localizationStore: LocalizationStore

    private var strings: AppStrings { AppStrings(language: localizationStore.language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !isCollapsed {
                Divider()
                logList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(strings.activityConsole, systemImage: "terminal")
                .font(.callout.weight(.semibold))
            if isCollapsed, let last = entries.last {
                Text(last.message).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(strings.clearLog) { onClear() }
                .buttonStyle(.borderless).font(.caption).disabled(entries.isEmpty)
            Button { isCollapsed.toggle() } label: {
                Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if entries.isEmpty {
                        Text(strings.noActivityYet).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    } else {
                        ForEach(entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                Image(systemName: glyph(entry.level)).foregroundStyle(color(entry.level)).font(.caption2)
                                Text(entry.message).font(.caption.monospaced())
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)
            .onChange(of: entries.count) { _ in
                if let last = entries.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func glyph(_ level: ActivityLevel) -> String {
        switch level {
        case .info: return "circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func color(_ level: ActivityLevel) -> Color {
        switch level {
        case .info: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}
```

- [ ] **Step 3: Restructure `ProjectDetailView.body` to dock the console + add the notice overlay**

In `ProjectDetailView.swift`, add a state field near the other `@State`s:

```swift
    @State private var consoleCollapsed = false
```

Replace the current `body`'s `ScrollView { VStack { … UploadProgressView(…) } .padding(20) }` with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    projectFields
                    accountFields
                    uploadActions
                    appStoreReviewActions
                }
                .padding(20)
            }
            Divider()
            ConsolePane(
                entries: viewModel.activityLog,
                isCollapsed: $consoleCollapsed,
                onClear: { viewModel.clearActivityLog() }
            )
        }
        .overlay(alignment: .top) { noticeBanner }
        .task(id: viewModel.latestBuildStatusTrigger) {
            await viewModel.refreshLatestBuildTestFlightStatusIfNeeded()
        }
        .fileImporter(
```

(Keep the existing `.fileImporter(…)` and everything after it exactly as-is — only the `ScrollView { … }` block and the `.task`/overlay placement change. The old `UploadProgressView(state:events:)` line is removed.)

Add the notice overlay view (near the other private view helpers):

```swift
    @ViewBuilder
    private var noticeBanner: some View {
        if let notice = viewModel.notice {
            HStack(spacing: 8) {
                Image(systemName: notice.level == .error ? "xmark.octagon.fill" : "checkmark.circle.fill")
                Text(notice.message).font(.callout).lineLimit(3)
                Spacer()
                if notice.level == .error {
                    Button { viewModel.dismissNotice() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                (notice.level == .error ? Color.red : Color.green).opacity(0.15),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(notice.level == .error ? Color.red : Color.green)
            .padding(.horizontal, 20).padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: notice.id) {
                guard notice.level == .success else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if viewModel.notice?.id == notice.id { viewModel.dismissNotice() }
            }
        }
    }
```

- [ ] **Step 4: Add the background-load spinner to the TestFlight distribution section**

In `ProjectDetailView.swift`, at the top of `distributionSection`'s `VStack`, add:

```swift
            if viewModel.isBackgroundLoadingTestFlight {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(strings.updatingTestFlightStatus).font(.caption).foregroundStyle(.secondary)
                }
            }
```

- [ ] **Step 5: Delete `UploadProgressView.swift`**

```bash
git rm Sources/ProjPostApp/Views/UploadProgressView.swift
```

- [ ] **Step 6: Build (no warnings) and run the full suite**

Run: `swift build` (expect `Build complete!`, no warnings) then `swift test` (expect all green — Core behavior unchanged by the view edits).

- [ ] **Step 7: Launch the dev app and verify by eye**

Package the debug build into `dist/JJPost-dev.app` and `open` it (bare `swift run` renders blank on this machine):

```bash
ROOT="$PWD"; APP="$ROOT/dist/JJPost-dev.app"; C="$APP/Contents"
rm -rf "$APP"; mkdir -p "$C/MacOS" "$C/Resources"
cp "$ROOT/.build/debug/ProjPostApp" "$C/MacOS/ProjPostApp"; chmod 755 "$C/MacOS/ProjPostApp"
cp -R "$ROOT/.build/debug/ProjPost_ProjPostApp.bundle" "$C/Resources/" 2>/dev/null || true
cp "$ROOT/Sources/ProjPostApp/Resources/AppIcon.icns" "$C/Resources/AppIcon.icns" 2>/dev/null || true
printf '%s' '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>ProjPostApp</string><key>CFBundleIdentifier</key><string>com.jjpost.app.dev</string><key>CFBundleName</key><string>JJPost Dev</string><key>CFBundleIconFile</key><string>AppIcon</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.1.0</string><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>' > "$C/Info.plist"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
open "$APP"
```

Verify by eye: the console is docked at the bottom and always visible; clicking "Upload to TestFlight" with an incomplete config immediately shows a red error banner at the top AND an error line in the console without scrolling; the console collapse chevron and Clear button work; entering a project auto-loads TestFlight status without dimming the whole panel.

- [ ] **Step 8: Commit**

```bash
git add Sources/ProjPostApp/Views/ConsolePane.swift Sources/ProjPostApp/Views/ProjectDetailView.swift Sources/ProjPostCore/Localization/AppStrings.swift
git commit -m "feat(ui): docked activity console + error banner/success toast"
```

---

## Self-Review

- **Spec coverage:** activity log → Task 1; every action logs → Task 2 (didSet on the four states covers upload/checks/beta/TF/App-Store outcomes and guard failures); bottom-docked console → Task 5; error banner + success toast → Task 5; non-locking background auto-load → Task 3; dead auto-link removal → Task 4; console/toast verified by build+launch → Task 5. All covered.
- **Placeholder scan:** every step has concrete code or exact deletion targets; no TBD/vague items.
- **Type consistency:** `ActivityLevel`/`ActivityEntry`/`ActivityNotice`, `activityLog`/`notice`, `recordActivity`, `clearActivityLog`/`dismissNotice`, `isBackgroundLoadingTestFlight`, and the string names (`appStoreReviewStatusRefreshed`, `activityConsole`, `clearLog`, `noActivityYet`) are used identically across tasks. The `didSet` init-fire behavior is handled by defaulting `activityLog`/`notice` and keeping init-time state values non-terminal.
