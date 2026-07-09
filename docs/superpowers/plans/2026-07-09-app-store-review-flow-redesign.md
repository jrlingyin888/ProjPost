# App Store Review Flow Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the App Store Review section into a state-driven guided flow — one primary CTA that follows the real review phase, a readiness checklist, withdraw and release actions, editable release strategy, and a single source of truth so status never self-contradicts.

**Architecture:** Add the missing App Store Connect endpoints (read active submission, cancel, patch release type, request release) to `AppStoreConnectClient`. Derive a pure `AppStoreReviewPhase` and a readiness checklist in Core from the snapshot. Rework `AppViewModel` so every action reloads the snapshot. `ProjectDetailView` becomes a thin renderer of phase + checklist + CTA.

**Tech Stack:** Swift 5.9, SwiftUI on macOS 13+, XCTest, App Store Connect API (JSON:API).

## Global Constraints

- No new third-party dependencies.
- Every new user-facing string is added to `AppStrings` in **both** English and Simplified Chinese via `text("English", "简体中文")`.
- All new logic lives in **ProjPostCore** with tests; `ProjectDetailView` stays a thin rendering layer.
- Every new `AppViewModel` action early-returns on `guard !isOperationRunning` and reloads the snapshot on completion.
- Screenshots stay read-only; a missing screenshot is a **yellow warning**, never a hard block.
- Scheduled-date (`SCHEDULED`) release editing is out of scope; the editable picker offers only Manual and Automatic-after-approval.
- The class `AppViewModel` is not `@MainActor`; async work that mutates published state hops through `await MainActor.run { … }` where the existing code does.
- Two test types conform to `AppStoreConnectClientProtocol` and BOTH must be updated whenever the protocol grows, or the suite won't compile: `FakeAppStoreConnectClient` in `Tests/ProjPostCoreTests/AppViewModelStateTests.swift` and `FakeASCClient` in `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`.

---

### Task 1: App Store Connect client — new endpoints

**Files:**
- Modify: `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`
- Modify: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift` (extend `FakeAppStoreConnectClient`)
- Modify: `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift` (extend `FakeASCClient`)
- Test: `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`

**Interfaces:**
- Produces (added to `AppStoreConnectClientProtocol`):
  - `fetchActiveReviewSubmission(appID: String) async throws -> ASCReviewSubmission?`
  - `cancelReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission`
  - `updateAppStoreVersionReleaseType(appStoreVersionID: String, releaseType: String) async throws -> ASCAppStoreVersion`
  - `requestAppStoreVersionRelease(appStoreVersionID: String) async throws`
- Consumes existing private helpers `get`, `send`, `sendNoContent`, `dataArray`, and mapper `mapReviewSubmission` / `mapAppStoreVersion`.

- [ ] **Step 1: Write the failing client tests**

Append to `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift` (inside the `AppStoreConnectClientTests` class):

```swift
func testFetchActiveReviewSubmissionReturnsNonCompleteSubmission() async throws {
    let transport = StubASCTransport(responses: [
        ASCTransportResponse(statusCode: 200, body: #"{"data":[{"id":"rs-done","type":"reviewSubmissions","attributes":{"state":"COMPLETE"}},{"id":"rs-active","type":"reviewSubmissions","attributes":{"state":"WAITING_FOR_REVIEW"}}]}"#)
    ])
    let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

    let submission = try await client.fetchActiveReviewSubmission(appID: "app-123")

    XCTAssertEqual(submission, ASCReviewSubmission(id: "rs-active", state: "WAITING_FOR_REVIEW"))
    let request = try XCTUnwrap(transport.requests.first)
    XCTAssertEqual(request.method, "GET")
    XCTAssertEqual(request.path, "/v1/reviewSubmissions")
    XCTAssertEqual(request.queryItems["filter[app]"], "app-123")
    XCTAssertEqual(request.queryItems["filter[platform]"], "IOS")
}

func testCancelReviewSubmissionSendsCanceledTrue() async throws {
    let transport = StubASCTransport(responses: [
        ASCTransportResponse(statusCode: 200, body: #"{"data":{"id":"rs-active","type":"reviewSubmissions","attributes":{"state":"CANCELING"}}}"#)
    ])
    let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

    let submission = try await client.cancelReviewSubmission(reviewSubmissionID: "rs-active")

    XCTAssertEqual(submission, ASCReviewSubmission(id: "rs-active", state: "CANCELING"))
    let request = try XCTUnwrap(transport.requests.first)
    XCTAssertEqual(request.method, "PATCH")
    XCTAssertEqual(request.path, "/v1/reviewSubmissions/rs-active")
    XCTAssertEqual(
        String(data: try XCTUnwrap(request.body), encoding: .utf8),
        #"{"data":{"attributes":{"canceled":true},"id":"rs-active","type":"reviewSubmissions"}}"#
    )
}

func testUpdateReleaseTypePatchesVersion() async throws {
    let transport = StubASCTransport(responses: [
        ASCTransportResponse(statusCode: 200, body: #"{"data":{"id":"version-123","type":"appStoreVersions","attributes":{"versionString":"1.2.6","appStoreState":"PREPARE_FOR_SUBMISSION","releaseType":"AFTER_APPROVAL"}}}"#)
    ])
    let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

    let version = try await client.updateAppStoreVersionReleaseType(appStoreVersionID: "version-123", releaseType: "AFTER_APPROVAL")

    XCTAssertEqual(version.releaseType, "AFTER_APPROVAL")
    let request = try XCTUnwrap(transport.requests.first)
    XCTAssertEqual(request.method, "PATCH")
    XCTAssertEqual(request.path, "/v1/appStoreVersions/version-123")
    XCTAssertEqual(
        String(data: try XCTUnwrap(request.body), encoding: .utf8),
        #"{"data":{"attributes":{"releaseType":"AFTER_APPROVAL"},"id":"version-123","type":"appStoreVersions"}}"#
    )
}

func testRequestReleasePostsReleaseRequest() async throws {
    let transport = StubASCTransport(responses: [
        ASCTransportResponse(statusCode: 201, body: #"{"data":{"id":"release-1","type":"appStoreVersionReleaseRequests"}}"#)
    ])
    let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

    try await client.requestAppStoreVersionRelease(appStoreVersionID: "version-123")

    let request = try XCTUnwrap(transport.requests.first)
    XCTAssertEqual(request.method, "POST")
    XCTAssertEqual(request.path, "/v1/appStoreVersionReleaseRequests")
    XCTAssertEqual(
        String(data: try XCTUnwrap(request.body), encoding: .utf8),
        #"{"data":{"relationships":{"appStoreVersion":{"data":{"id":"version-123","type":"appStoreVersions"}}},"type":"appStoreVersionReleaseRequests"}}"#
    )
}
```

- [ ] **Step 2: Run the tests to verify they fail to compile**

Run: `swift test --filter ProjPostCoreTests.AppStoreConnectClientTests`
Expected: FAIL — `value of type 'AppStoreConnectClient' has no member 'fetchActiveReviewSubmission'`.

- [ ] **Step 3: Add the four protocol methods**

In `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`, add to the `AppStoreConnectClientProtocol` declaration (after `submitReviewSubmission`):

```swift
    func fetchActiveReviewSubmission(appID: String) async throws -> ASCReviewSubmission?
    func cancelReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission
    func updateAppStoreVersionReleaseType(appStoreVersionID: String, releaseType: String) async throws -> ASCAppStoreVersion
    func requestAppStoreVersionRelease(appStoreVersionID: String) async throws
```

- [ ] **Step 4: Implement the four methods**

In the same file, after `submitReviewSubmission(...)` (around line 662):

```swift
    public func fetchActiveReviewSubmission(appID: String) async throws -> ASCReviewSubmission? {
        let json = try await get(
            path: "/v1/reviewSubmissions",
            query: ["filter[app]": appID, "filter[platform]": "IOS"]
        )
        let submissions = try dataArray(from: json).map(Self.mapReviewSubmission)
        return submissions.first { $0.state != "COMPLETE" }
    }

    public func cancelReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission {
        let body: [String: Any] = [
            "data": [
                "type": "reviewSubmissions",
                "id": reviewSubmissionID,
                "attributes": ["canceled": true]
            ]
        ]
        let json = try await send(method: "PATCH", path: "/v1/reviewSubmissions/\(reviewSubmissionID)", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapReviewSubmission(data)
    }

    public func updateAppStoreVersionReleaseType(appStoreVersionID: String, releaseType: String) async throws -> ASCAppStoreVersion {
        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "id": appStoreVersionID,
                "attributes": ["releaseType": releaseType]
            ]
        ]
        let json = try await send(method: "PATCH", path: "/v1/appStoreVersions/\(appStoreVersionID)", query: [:], jsonBody: body)
        guard let data = json["data"] as? [String: Any] else {
            throw AppStoreConnectError.malformedResponse
        }
        return Self.mapAppStoreVersion(data)
    }

    public func requestAppStoreVersionRelease(appStoreVersionID: String) async throws {
        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersionReleaseRequests",
                "relationships": [
                    "appStoreVersion": [
                        "data": ["type": "appStoreVersions", "id": appStoreVersionID]
                    ]
                ]
            ]
        ]
        try await sendNoContent(method: "POST", path: "/v1/appStoreVersionReleaseRequests", query: [:], jsonBody: body)
    }
```

- [ ] **Step 5: Extend `FakeAppStoreConnectClient` so the VM test target compiles**

In `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`, in `FakeAppStoreConnectClient`:

Add a stored property + init parameter (put the property near the other `var`s, and the param at the end of `init` before the closing paren, with a default):

```swift
    var activeReviewSubmission: ASCReviewSubmission?
    private(set) var fetchedActiveReviewSubmissionAppIDs: [String] = []
    private(set) var canceledReviewSubmissionIDs: [String] = []
    private(set) var updatedReleaseTypes: [(appStoreVersionID: String, releaseType: String)] = []
    private(set) var releasedAppStoreVersionIDs: [String] = []
```

Add `activeReviewSubmission: ASCReviewSubmission? = nil` as the final `init` parameter and `self.activeReviewSubmission = activeReviewSubmission` in the body. Then add these methods (make `createReviewSubmission` / `submitReviewSubmission` stateful so a later reload sees the new state):

```swift
    func fetchActiveReviewSubmission(appID: String) async throws -> ASCReviewSubmission? {
        fetchedActiveReviewSubmissionAppIDs.append(appID)
        return activeReviewSubmission
    }

    func cancelReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission {
        canceledReviewSubmissionIDs.append(reviewSubmissionID)
        activeReviewSubmission = nil
        return ASCReviewSubmission(id: reviewSubmissionID, state: "CANCELING")
    }

    func updateAppStoreVersionReleaseType(appStoreVersionID: String, releaseType: String) async throws -> ASCAppStoreVersion {
        updatedReleaseTypes.append((appStoreVersionID, releaseType))
        if let index = appStoreVersions.firstIndex(where: { $0.id == appStoreVersionID }) {
            let current = appStoreVersions[index]
            let updated = ASCAppStoreVersion(id: current.id, versionString: current.versionString, state: current.state, releaseType: releaseType)
            appStoreVersions[index] = updated
            return updated
        }
        return ASCAppStoreVersion(id: appStoreVersionID, versionString: "", state: nil, releaseType: releaseType)
    }

    func requestAppStoreVersionRelease(appStoreVersionID: String) async throws {
        releasedAppStoreVersionIDs.append(appStoreVersionID)
    }
```

Then modify the EXISTING fake `createReviewSubmission` and `submitReviewSubmission` to update `activeReviewSubmission`:

```swift
    func createReviewSubmission(appID: String) async throws -> ASCReviewSubmission {
        createdReviewSubmissionAppIDs.append(appID)
        activeReviewSubmission = reviewSubmission
        return reviewSubmission
    }

    func submitReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission {
        submittedReviewSubmissionIDs.append(reviewSubmissionID)
        let submitted = ASCReviewSubmission(id: reviewSubmissionID, state: "WAITING_FOR_REVIEW")
        activeReviewSubmission = submitted
        return submitted
    }
```

- [ ] **Step 6: Extend `FakeASCClient` so the config-check test compiles**

In `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`, add to `FakeASCClient` (after its `submitReviewSubmission`):

```swift
    func fetchActiveReviewSubmission(appID: String) async throws -> ASCReviewSubmission? { nil }
    func cancelReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission { ASCReviewSubmission(id: reviewSubmissionID, state: nil) }
    func updateAppStoreVersionReleaseType(appStoreVersionID: String, releaseType: String) async throws -> ASCAppStoreVersion { ASCAppStoreVersion(id: appStoreVersionID, versionString: "", state: nil, releaseType: releaseType) }
    func requestAppStoreVersionRelease(appStoreVersionID: String) async throws {}
```

> Note: If `FakeASCClient` does not already implement `createReviewSubmission`/`createReviewSubmissionItem`/`submitReviewSubmission`, add trivial stubs the same way — the file must fully conform to the protocol.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `swift test --filter ProjPostCoreTests.AppStoreConnectClientTests`
Expected: PASS (all four new tests green, existing green).

- [ ] **Step 8: Commit**

```bash
git add Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift
git commit -m "feat(asc): add active-submission, cancel, release-type, and release-request endpoints"
```

---

### Task 2: Review phase + readiness checklist (pure Core)

**Files:**
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Test: `Tests/ProjPostCoreTests/DomainModelsTests.swift`

**Interfaces:**
- Consumes `AppStoreReviewSnapshot`, `AppStoreReviewBuildOption`, `ASCAppStoreVersionLocalization`, `ASCAppStoreReviewDetail`.
- Produces:
  - `AppStoreReviewSnapshot.reviewSubmissionID: String?` (new stored property, default `nil`)
  - `enum AppStoreReviewPhase { case noVersion, editable, inReview, canceling, pendingDeveloperRelease, releasing, live, replaced }`
  - `AppStoreReviewPhase.init(versionState:submissionState:)` and `AppStoreReviewPhase.resolve(snapshot:)`
  - `enum ReviewReadinessSeverity { case green, yellow, red }`
  - `enum ReviewReadinessKind { case buildValid, whatsNewFilled, reviewContactComplete, screenshotsPresent, exportCompliance }`
  - `struct ReviewReadinessItem { kind; severity; detail: String? }`
  - `enum AppStoreReviewReadiness { static func evaluate(snapshot:) -> [ReviewReadinessItem]; static func blocks(_:) -> Bool }`

- [ ] **Step 1: Write failing tests for phase derivation**

Append to `Tests/ProjPostCoreTests/DomainModelsTests.swift`:

```swift
func testReviewPhaseResolvesFromSubmissionAndVersionState() {
    XCTAssertEqual(AppStoreReviewPhase.resolve(snapshot: nil), .noVersion)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "PREPARE_FOR_SUBMISSION", submissionState: nil), .editable)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "REJECTED", submissionState: nil), .editable)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "PREPARE_FOR_SUBMISSION", submissionState: "WAITING_FOR_REVIEW"), .inReview)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "IN_REVIEW", submissionState: nil), .inReview)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "PREPARE_FOR_SUBMISSION", submissionState: "CANCELING"), .canceling)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "PENDING_DEVELOPER_RELEASE", submissionState: nil), .pendingDeveloperRelease)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "PENDING_APPLE_RELEASE", submissionState: nil), .releasing)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "READY_FOR_SALE", submissionState: nil), .live)
    XCTAssertEqual(AppStoreReviewPhase(versionState: "REPLACED_WITH_NEW_VERSION", submissionState: nil), .replaced)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.DomainModelsTests`
Expected: FAIL — `cannot find 'AppStoreReviewPhase' in scope`.

- [ ] **Step 3: Add `reviewSubmissionID` to the snapshot and the phase enum**

In `Sources/ProjPostCore/Models/DomainModels.swift`, add to `AppStoreReviewSnapshot` a stored property `public var reviewSubmissionID: String?` and a matching `init` parameter `reviewSubmissionID: String? = nil` (place it right after `reviewSubmissionState`, assign `self.reviewSubmissionID = reviewSubmissionID`). Then add, after the `AppStoreReviewState` enum:

```swift
public enum AppStoreReviewPhase: Equatable {
    case noVersion
    case editable
    case inReview
    case canceling
    case pendingDeveloperRelease
    case releasing
    case live
    case replaced

    public init(versionState: String?, submissionState: String?) {
        switch submissionState {
        case "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES":
            self = .inReview
            return
        case "CANCELING":
            self = .canceling
            return
        default:
            break
        }
        switch versionState {
        case "WAITING_FOR_REVIEW", "IN_REVIEW":
            self = .inReview
        case "PENDING_DEVELOPER_RELEASE":
            self = .pendingDeveloperRelease
        case "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE", "PROCESSING_FOR_DISTRIBUTION":
            self = .releasing
        case "READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "ACCEPTED":
            self = .live
        case "REPLACED_WITH_NEW_VERSION":
            self = .replaced
        default:
            self = .editable
        }
    }

    public static func resolve(snapshot: AppStoreReviewSnapshot?) -> AppStoreReviewPhase {
        guard let snapshot else { return .noVersion }
        return AppStoreReviewPhase(versionState: snapshot.versionState, submissionState: snapshot.reviewSubmissionState)
    }
}
```

- [ ] **Step 4: Run to verify the phase test passes**

Run: `swift test --filter ProjPostCoreTests.DomainModelsTests`
Expected: PASS.

- [ ] **Step 5: Write failing tests for the readiness checklist**

Append to `Tests/ProjPostCoreTests/DomainModelsTests.swift`:

```swift
private func makeReviewSnapshot(
    builds: [AppStoreReviewBuildOption] = [AppStoreReviewBuildOption(id: "b1", buildNumber: "1", processingState: "VALID", isBound: false)],
    selectedBuildID: String? = "b1",
    versionState: String? = "PREPARE_FOR_SUBMISSION",
    reviewDetail: ASCAppStoreReviewDetail? = ASCAppStoreReviewDetail(id: "d", contactFirstName: "A", contactLastName: "B", contactPhone: "1", contactEmail: "a@b.c", demoAccountName: nil, demoAccountPassword: nil, demoAccountRequired: false, notes: nil),
    localizations: [ASCAppStoreVersionLocalization] = [ASCAppStoreVersionLocalization(id: "l", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: "新内容")],
    screenshotSets: [AppStoreReviewScreenshotSet] = [AppStoreReviewScreenshotSet(id: "s", localizationID: "l", locale: "zh-Hans", screenshotDisplayType: "APP_IPHONE_65", screenshots: [ASCAppScreenshot(id: "sc", fileName: "a.png", fileSize: 1, imageURLTemplate: nil, width: 1, height: 1, assetDeliveryState: "COMPLETE")])]
) -> AppStoreReviewSnapshot {
    AppStoreReviewSnapshot(
        appID: "app", appStoreVersionID: "v", versionString: "1.2.6", versionState: versionState, releaseType: "MANUAL",
        selectedBuildID: selectedBuildID, boundBuildID: nil, builds: builds, reviewDetail: reviewDetail,
        localizations: localizations, screenshotSets: screenshotSets, reviewSubmissionState: nil
    )
}

func testReadinessAllGreenDoesNotBlock() {
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot())
    XCTAssertFalse(AppStoreReviewReadiness.blocks(items))
    XCTAssertEqual(items.first(where: { $0.kind == .buildValid })?.severity, .green)
    XCTAssertEqual(items.first(where: { $0.kind == .screenshotsPresent })?.severity, .green)
}

func testReadinessMissingBuildBlocksRed() {
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(selectedBuildID: nil))
    XCTAssertTrue(AppStoreReviewReadiness.blocks(items))
    XCTAssertEqual(items.first(where: { $0.kind == .buildValid })?.severity, .red)
}

func testReadinessProcessingBuildBlocksRed() {
    let snapshot = makeReviewSnapshot(builds: [AppStoreReviewBuildOption(id: "b1", buildNumber: "1", processingState: "PROCESSING", isBound: false)])
    let items = AppStoreReviewReadiness.evaluate(snapshot: snapshot)
    XCTAssertEqual(items.first(where: { $0.kind == .buildValid })?.severity, .red)
}

func testReadinessIncompleteContactBlocksRed() {
    let detail = ASCAppStoreReviewDetail(id: "d", contactFirstName: "A", contactLastName: nil, contactPhone: nil, contactEmail: "a@b.c", demoAccountName: nil, demoAccountPassword: nil, demoAccountRequired: false, notes: nil)
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(reviewDetail: detail))
    XCTAssertEqual(items.first(where: { $0.kind == .reviewContactComplete })?.severity, .red)
}

func testReadinessMissingWhatsNewOnUpdateVersionBlocksRed() {
    let locs = [ASCAppStoreVersionLocalization(id: "l", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: "  ")]
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(localizations: locs))
    XCTAssertEqual(items.first(where: { $0.kind == .whatsNewFilled })?.severity, .red)
}

func testReadinessFirstVersionWithoutWhatsNewIsGreen() {
    let locs = [ASCAppStoreVersionLocalization(id: "l", locale: "zh-Hans", description: nil, keywords: nil, marketingURL: nil, promotionalText: nil, supportURL: nil, whatsNew: nil)]
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(localizations: locs))
    XCTAssertEqual(items.first(where: { $0.kind == .whatsNewFilled })?.severity, .green)
}

func testReadinessMissingScreenshotsWarnsYellowNotBlock() {
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(screenshotSets: []))
    XCTAssertEqual(items.first(where: { $0.kind == .screenshotsPresent })?.severity, .yellow)
    XCTAssertFalse(AppStoreReviewReadiness.blocks(items))
}

func testReadinessExportComplianceStateBlocksRed() {
    let items = AppStoreReviewReadiness.evaluate(snapshot: makeReviewSnapshot(versionState: "WAITING_FOR_EXPORT_COMPLIANCE"))
    XCTAssertEqual(items.first(where: { $0.kind == .exportCompliance })?.severity, .red)
}
```

- [ ] **Step 6: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.DomainModelsTests`
Expected: FAIL — `cannot find 'AppStoreReviewReadiness' in scope`.

- [ ] **Step 7: Implement the readiness types**

In `DomainModels.swift`, after `AppStoreReviewPhase`:

```swift
public enum ReviewReadinessSeverity: Equatable {
    case green
    case yellow
    case red
}

public enum ReviewReadinessKind: Equatable {
    case buildValid
    case whatsNewFilled
    case reviewContactComplete
    case screenshotsPresent
    case exportCompliance
}

public struct ReviewReadinessItem: Equatable, Identifiable {
    public var kind: ReviewReadinessKind
    public var severity: ReviewReadinessSeverity
    public var detail: String?

    public init(kind: ReviewReadinessKind, severity: ReviewReadinessSeverity, detail: String? = nil) {
        self.kind = kind
        self.severity = severity
        self.detail = detail
    }

    public var id: String { "\(kind)" }
}

public enum AppStoreReviewReadiness {
    public static func evaluate(snapshot: AppStoreReviewSnapshot) -> [ReviewReadinessItem] {
        [
            buildItem(snapshot),
            whatsNewItem(snapshot),
            contactItem(snapshot),
            screenshotItem(snapshot),
            exportComplianceItem(snapshot)
        ]
    }

    public static func blocks(_ items: [ReviewReadinessItem]) -> Bool {
        items.contains { $0.severity == .red }
    }

    private static func buildItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        guard let selectedBuildID = snapshot.selectedBuildID,
              let build = snapshot.builds.first(where: { $0.id == selectedBuildID }) else {
            return ReviewReadinessItem(kind: .buildValid, severity: .red)
        }
        let isValid = build.processingState == "VALID"
        return ReviewReadinessItem(kind: .buildValid, severity: isValid ? .green : .red, detail: build.buildNumber)
    }

    private static func whatsNewItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        let supportsWhatsNew = snapshot.localizations.contains { $0.whatsNew != nil }
        guard supportsWhatsNew else {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .green)
        }
        func filled(_ loc: ASCAppStoreVersionLocalization) -> Bool {
            (loc.whatsNew?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
        let applicable = snapshot.localizations.filter { $0.whatsNew != nil }
        let emptyLocales = applicable.filter { !filled($0) }.map(\.locale)
        if emptyLocales.count == applicable.count {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .red)
        } else if emptyLocales.isEmpty {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .green)
        } else {
            return ReviewReadinessItem(kind: .whatsNewFilled, severity: .yellow, detail: emptyLocales.joined(separator: ", "))
        }
    }

    private static func contactItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        func present(_ value: String?) -> Bool { value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        let detail = snapshot.reviewDetail
        let complete = present(detail?.contactFirstName) && present(detail?.contactLastName)
            && present(detail?.contactPhone) && present(detail?.contactEmail)
        return ReviewReadinessItem(kind: .reviewContactComplete, severity: complete ? .green : .red)
    }

    private static func screenshotItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        let total = snapshot.screenshotSets.reduce(0) { $0 + $1.screenshots.count }
        return ReviewReadinessItem(kind: .screenshotsPresent, severity: total > 0 ? .green : .yellow)
    }

    private static func exportComplianceItem(_ snapshot: AppStoreReviewSnapshot) -> ReviewReadinessItem {
        let waiting = snapshot.versionState == "WAITING_FOR_EXPORT_COMPLIANCE"
        return ReviewReadinessItem(kind: .exportCompliance, severity: waiting ? .red : .green)
    }
}
```

- [ ] **Step 8: Run to verify all Task 2 tests pass**

Run: `swift test --filter ProjPostCoreTests.DomainModelsTests`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Sources/ProjPostCore/Models/DomainModels.swift Tests/ProjPostCoreTests/DomainModelsTests.swift
git commit -m "feat(core): add AppStoreReviewPhase and readiness checklist"
```

---

### Task 3: ViewModel — load submission state, rework submit

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes Task 1 (`fetchActiveReviewSubmission`) and the reworked submit path.
- Produces: `submitSelectedAppStoreReview()` reworked to auto-bind + reuse/create submission + reload; `loadAppStoreReviewSnapshot` populates `reviewSubmissionID` and `reviewSubmissionState`.

- [ ] **Step 1: Write failing test — load populates submission state**

Append to `AppViewModelStateTests.swift` (reuse the `makeProject` / account setup pattern from `testRefreshAppStoreReviewStatusDefaultsSelectedBuildFromLastSuccessfulUpload`):

```swift
func testRefreshAppStoreReviewLoadsActiveSubmissionState() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
        appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "WAITING_FOR_REVIEW", releaseType: "MANUAL")],
        activeReviewSubmission: ASCReviewSubmission(id: "rs-1", state: "WAITING_FOR_REVIEW")
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )

    await viewModel.refreshAppStoreReviewStatus()

    guard case let .loaded(snapshot) = viewModel.appStoreReviewState else { return XCTFail("expected loaded") }
    XCTAssertEqual(snapshot.reviewSubmissionID, "rs-1")
    XCTAssertEqual(snapshot.reviewSubmissionState, "WAITING_FOR_REVIEW")
    XCTAssertEqual(AppStoreReviewPhase.resolve(snapshot: snapshot), .inReview)
    XCTAssertEqual(appStoreConnect.fetchedActiveReviewSubmissionAppIDs, ["app-123"])
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testRefreshAppStoreReviewLoadsActiveSubmissionState`
Expected: FAIL — `reviewSubmissionID` is nil.

- [ ] **Step 3: Populate submission state in `loadAppStoreReviewSnapshot`**

In `AppViewModel.swift`, inside `loadAppStoreReviewSnapshot(createIfMissing:)`, after the app/version are resolved and before building the snapshot, add:

```swift
        let activeSubmission = try await client.fetchActiveReviewSubmission(appID: app.id)
```

Then in the `AppStoreReviewSnapshot(...)` initializer at the end of that function, set:

```swift
            reviewSubmissionID: activeSubmission?.id,
            reviewSubmissionState: activeSubmission?.state
```

(Replace the current hard-coded `reviewSubmissionState: nil`.)

- [ ] **Step 4: Run to verify the load test passes**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testRefreshAppStoreReviewLoadsActiveSubmissionState`
Expected: PASS.

- [ ] **Step 5: Write failing tests — submit auto-binds, reuses, reloads**

Append:

```swift
func testSubmitAutoBindsThenSubmitsAndReloads() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
        appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")],
        boundAppStoreVersionBuildIDs: [:]
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )
    await viewModel.refreshAppStoreReviewStatus()
    viewModel.selectAppStoreReviewBuild("build-1")

    await viewModel.submitSelectedAppStoreReview()

    XCTAssertEqual(appStoreConnect.updatedAppStoreVersionBuilds, [FakeAppStoreConnectClient.UpdatedAppStoreVersionBuild(appStoreVersionID: "version-123", buildID: "build-1")])
    XCTAssertEqual(appStoreConnect.createdReviewSubmissionAppIDs, ["app-123"])
    XCTAssertEqual(appStoreConnect.submittedReviewSubmissionIDs.count, 1)
    // reloaded snapshot reflects the submitted state, no stale badge
    if case let .succeeded(_, snapshot) = viewModel.appStoreReviewState {
        XCTAssertEqual(snapshot?.reviewSubmissionState, "WAITING_FOR_REVIEW")
    } else if case let .loaded(snapshot) = viewModel.appStoreReviewState {
        XCTAssertEqual(snapshot.reviewSubmissionState, "WAITING_FOR_REVIEW")
    } else {
        XCTFail("expected succeeded/loaded after submit")
    }
}

func testSubmitReusesDanglingReadySubmissionWithoutCreating() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
        appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")],
        boundAppStoreVersionBuildIDs: ["version-123": "build-1"],
        activeReviewSubmission: ASCReviewSubmission(id: "rs-ready", state: "READY_FOR_REVIEW")
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )
    await viewModel.refreshAppStoreReviewStatus()
    viewModel.selectAppStoreReviewBuild("build-1")

    await viewModel.submitSelectedAppStoreReview()

    XCTAssertEqual(appStoreConnect.createdReviewSubmissionAppIDs, [], "should reuse the dangling READY_FOR_REVIEW submission")
    XCTAssertEqual(appStoreConnect.submittedReviewSubmissionIDs, ["rs-ready"])
}
```

- [ ] **Step 6: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testSubmitAutoBindsThenSubmitsAndReloads`
Expected: FAIL (current submit requires a pre-bound build and never auto-binds / reuses).

- [ ] **Step 7: Rework `submitSelectedAppStoreReview`**

Replace the body of `submitSelectedAppStoreReview()` in `AppViewModel.swift` with:

```swift
    public func submitSelectedAppStoreReview() async {
        guard !isOperationRunning else { return }
        guard var snapshot = currentAppStoreReviewSnapshot else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: nil)
            return
        }
        guard let selectedBuildID = snapshot.selectedBuildID else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.buildNotSelected), snapshot: snapshot)
            return
        }
        guard let account = accountProfile else {
            appStoreReviewState = .failed(message: strings.selectAppleAccountBeforeRefreshingTestFlightStatus, snapshot: snapshot)
            return
        }

        appStoreReviewState = .submitting(snapshot)
        do {
            let client = appStoreConnectClient(for: account)

            if snapshot.boundBuildID != selectedBuildID {
                try await client.updateAppStoreVersionBuild(appStoreVersionID: snapshot.appStoreVersionID, buildID: selectedBuildID)
                snapshot.boundBuildID = selectedBuildID
            }

            let submissionID: String
            if let existing = try await client.fetchActiveReviewSubmission(appID: snapshot.appID), existing.state == "READY_FOR_REVIEW" {
                submissionID = existing.id
            } else {
                let created = try await client.createReviewSubmission(appID: snapshot.appID)
                submissionID = created.id
                _ = try await client.createReviewSubmissionItem(reviewSubmissionID: submissionID, appStoreVersionID: snapshot.appStoreVersionID)
            }

            let submitted = try await client.submitReviewSubmission(reviewSubmissionID: submissionID)
            let reloaded = try await loadAppStoreReviewSnapshot(createIfMissing: false)
            appStoreReviewState = .succeeded(
                message: strings.appStoreReviewSubmitted(state: submitted.state ?? strings.appStoreReviewStatusSubmitted),
                snapshot: reloaded.snapshot
            )
        } catch {
            appStoreReviewState = .failed(message: strings.appStoreReviewSubmitFailed(error), snapshot: snapshot)
        }
    }
```

- [ ] **Step 8: Run to verify Task 3 tests pass**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests`
Expected: PASS. Note: the pre-existing `testBindSelectedAppStoreBuildUsesUserSelectedBuild` still passes (the `bindSelectedAppStoreReviewBuild` method is unchanged in this task).

- [ ] **Step 9: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat(vm): load active submission and rework submit to auto-bind, reuse, reload"
```

---

### Task 4: ViewModel — cancel, release-type, release actions

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift` (failure-message helpers)
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes Task 1 (`cancelReviewSubmission`, `updateAppStoreVersionReleaseType`, `requestAppStoreVersionRelease`).
- Produces: `cancelAppStoreReview()`, `updateAppStoreReviewReleaseType(_:)`, `releaseApprovedVersion()`.

- [ ] **Step 1: Write failing tests**

Append to `AppViewModelStateTests.swift`:

```swift
func testCancelAppStoreReviewCancelsAndReloads() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
        appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")],
        activeReviewSubmission: ASCReviewSubmission(id: "rs-1", state: "WAITING_FOR_REVIEW")
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )
    await viewModel.refreshAppStoreReviewStatus()

    await viewModel.cancelAppStoreReview()

    XCTAssertEqual(appStoreConnect.canceledReviewSubmissionIDs, ["rs-1"])
    guard case let .loaded(snapshot) = viewModel.appStoreReviewState else { return XCTFail("expected loaded") }
    XCTAssertNil(snapshot.reviewSubmissionID) // active submission cleared after cancel
}

func testUpdateReleaseTypePatchesAndReloads() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
        appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")]
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )
    await viewModel.refreshAppStoreReviewStatus()

    await viewModel.updateAppStoreReviewReleaseType("AFTER_APPROVAL")

    XCTAssertEqual(appStoreConnect.updatedReleaseTypes.map(\.releaseType), ["AFTER_APPROVAL"])
    guard case let .loaded(snapshot) = viewModel.appStoreReviewState else { return XCTFail("expected loaded") }
    XCTAssertEqual(snapshot.releaseType, "AFTER_APPROVAL")
}

func testReleaseApprovedVersionRequestsRelease() async {
    let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
        appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PENDING_DEVELOPER_RELEASE", releaseType: "MANUAL")]
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
    )
    await viewModel.refreshAppStoreReviewStatus()

    await viewModel.releaseApprovedVersion()

    XCTAssertEqual(appStoreConnect.releasedAppStoreVersionIDs, ["version-123"])
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests/testCancelAppStoreReviewCancelsAndReloads`
Expected: FAIL — `value of type 'AppViewModel' has no member 'cancelAppStoreReview'`.

- [ ] **Step 3: Add the three failure-message helpers to `AppStrings`**

In `AppStrings.swift`, near the other `appStoreReview...Failed` helpers (around line 415-427):

```swift
    public func appStoreReviewCancelFailed(_ error: Error) -> String {
        text("Failed to withdraw the review submission: \(error)", "撤销审核提交失败：\(error)")
    }
    public func appStoreReviewReleaseTypeFailed(_ error: Error) -> String {
        text("Failed to update the release strategy: \(error)", "更新发布策略失败：\(error)")
    }
    public func appStoreReviewReleaseFailed(_ error: Error) -> String {
        text("Failed to release to the App Store: \(error)", "发布到 App Store 失败：\(error)")
    }
```

- [ ] **Step 4: Implement the three ViewModel actions**

In `AppViewModel.swift`, after `submitSelectedAppStoreReview()`:

```swift
    public func cancelAppStoreReview() async {
        guard !isOperationRunning else { return }
        guard let snapshot = currentAppStoreReviewSnapshot else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: nil)
            return
        }
        guard let submissionID = snapshot.reviewSubmissionID else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: snapshot)
            return
        }
        guard let account = accountProfile else {
            appStoreReviewState = .failed(message: strings.selectAppleAccountBeforeRefreshingTestFlightStatus, snapshot: snapshot)
            return
        }

        appStoreReviewState = .submitting(snapshot)
        do {
            let client = appStoreConnectClient(for: account)
            _ = try await client.cancelReviewSubmission(reviewSubmissionID: submissionID)
            let reloaded = try await loadAppStoreReviewSnapshot(createIfMissing: false)
            appStoreReviewState = .loaded(reloaded.snapshot)
        } catch {
            appStoreReviewState = .failed(message: strings.appStoreReviewCancelFailed(error), snapshot: snapshot)
        }
    }

    public func updateAppStoreReviewReleaseType(_ releaseType: String) async {
        guard !isOperationRunning else { return }
        guard let snapshot = currentAppStoreReviewSnapshot else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: nil)
            return
        }
        guard let account = accountProfile else {
            appStoreReviewState = .failed(message: strings.selectAppleAccountBeforeRefreshingTestFlightStatus, snapshot: snapshot)
            return
        }

        appStoreReviewState = .saving(snapshot)
        do {
            let client = appStoreConnectClient(for: account)
            _ = try await client.updateAppStoreVersionReleaseType(appStoreVersionID: snapshot.appStoreVersionID, releaseType: releaseType)
            let reloaded = try await loadAppStoreReviewSnapshot(createIfMissing: false)
            appStoreReviewState = .loaded(reloaded.snapshot)
        } catch {
            appStoreReviewState = .failed(message: strings.appStoreReviewReleaseTypeFailed(error), snapshot: snapshot)
        }
    }

    public func releaseApprovedVersion() async {
        guard !isOperationRunning else { return }
        guard let snapshot = currentAppStoreReviewSnapshot else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: nil)
            return
        }
        guard let account = accountProfile else {
            appStoreReviewState = .failed(message: strings.selectAppleAccountBeforeRefreshingTestFlightStatus, snapshot: snapshot)
            return
        }

        appStoreReviewState = .submitting(snapshot)
        do {
            let client = appStoreConnectClient(for: account)
            try await client.requestAppStoreVersionRelease(appStoreVersionID: snapshot.appStoreVersionID)
            let reloaded = try await loadAppStoreReviewSnapshot(createIfMissing: false)
            appStoreReviewState = .loaded(reloaded.snapshot)
        } catch {
            appStoreReviewState = .failed(message: strings.appStoreReviewReleaseFailed(error), snapshot: snapshot)
        }
    }
```

- [ ] **Step 5: Run to verify Task 4 tests pass**

Run: `swift test --filter ProjPostCoreTests.AppViewModelStateTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Sources/ProjPostCore/Localization/AppStrings.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat(vm): add withdraw, release-strategy, and release-to-store actions"
```

---

### Task 5: UI — state-driven CTA, badge, checklist, release picker

**Files:**
- Modify: `Sources/ProjPostApp/Views/ProjectDetailView.swift`
- Modify: `Sources/ProjPostCore/Localization/AppStrings.swift`

**Interfaces:**
- Consumes `AppStoreReviewPhase.resolve(snapshot:)`, `AppStoreReviewReadiness.evaluate/blocks`, and the ViewModel actions `submitSelectedAppStoreReview`, `cancelAppStoreReview`, `releaseApprovedVersion`, `updateAppStoreReviewReleaseType`, `selectAppStoreReviewBuild`, `prepareAppStoreReviewVersion`, `refreshAppStoreReviewStatus`.

- [ ] **Step 1: Add the new UI strings (both languages)**

In `AppStrings.swift`, after `appStoreReviewStatusSubmitted` (line 185):

```swift
    public var submitForReview: String { text("Submit for Review", "提交审核") }
    public var submittingForReview: String { text("Submitting…", "提交中…") }
    public var withdrawReview: String { text("Withdraw", "撤销提审") }
    public var withdrawingReview: String { text("Withdrawing…", "撤销中…") }
    public var releaseToAppStore: String { text("Release to App Store", "发布到 App Store") }
    public var releasingToAppStore: String { text("Releasing…", "发布中…") }
    public var submissionReadiness: String { text("Submission readiness", "提交就绪") }
    public var readinessBuildValid: String { text("Build selected and VALID", "构建已选择且 VALID") }
    public var readinessWhatsNew: String { text("What's New filled", "更新说明已填") }
    public var readinessContact: String { text("Review contact complete", "审核联系信息完整") }
    public var readinessScreenshots: String { text("Screenshots present", "已有截图") }
    public var readinessExport: String { text("Export compliance", "出口合规") }
    public var readinessScreenshotsHint: String { text("Add screenshots in App Store Connect", "请在 App Store Connect 补充截图") }
    public var withdrawReviewConfirm: String { text("Withdraw this version from review?", "确定撤销该版本的提审？") }
    public var releaseNowConfirm: String { text("Release this version to the App Store now?", "现在把该版本发布到 App Store？") }
    public var createStoreVersionAction: String { text("Create store version", "创建商店版本") }
    public func reviewPhaseBadge(_ phase: AppStoreReviewPhase) -> String {
        switch phase {
        case .noVersion: return text("No version", "无版本")
        case .editable: return text("Prepare for Submission", "待提交")
        case .inReview: return text("In Review", "审核中")
        case .canceling: return text("Canceling", "撤销中")
        case .pendingDeveloperRelease: return text("Pending Release", "待发布")
        case .releasing: return text("Releasing", "发布中")
        case .live: return text("On the App Store", "已上架")
        case .replaced: return text("Replaced", "已替换")
        }
    }
```

- [ ] **Step 2: Replace `appStoreReviewActions` with the state-driven layout**

In `ProjectDetailView.swift`, replace the whole `appStoreReviewActions` computed property (currently lines ~328-396) with:

```swift
    private var appStoreReviewActions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    reviewPhaseBadgeView
                    Spacer()
                    Button {
                        Task { await viewModel.refreshAppStoreReviewStatus() }
                    } label: {
                        Label(strings.refreshStoreStatus, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canQueryAppStoreReviewStatus || viewModel.isOperationRunning)
                    appStoreReviewPrimaryButton
                }

                if let snapshot = appStoreReviewSnapshot {
                    appStoreReviewSnapshotView(snapshot)
                    reviewReadinessView(snapshot)
                } else {
                    HStack {
                        placeholderRow(title: strings.appStoreReview, value: strings.appStoreReviewNoVersionLoaded)
                        Spacer()
                        Button {
                            Task { await viewModel.prepareAppStoreReviewVersion() }
                        } label: {
                            appStoreReviewOperationLabel(title: strings.createStoreVersionAction, systemImage: "square.stack.3d.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.canQueryAppStoreReviewStatus || viewModel.isOperationRunning)
                    }
                }

                if let appStoreReviewStatusText {
                    Text(appStoreReviewStatusText)
                        .font(.caption)
                        .foregroundStyle(appStoreReviewStatusColor)
                }
            }
        } label: {
            Label(strings.appStoreReview, systemImage: "app.badge")
        }
    }

    private var reviewPhase: AppStoreReviewPhase {
        AppStoreReviewPhase.resolve(snapshot: appStoreReviewSnapshot)
    }

    private var reviewPhaseBadgeView: some View {
        Text(strings.reviewPhaseBadge(reviewPhase))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(reviewPhaseColor.opacity(0.15), in: Capsule())
            .foregroundStyle(reviewPhaseColor)
    }

    private var reviewPhaseColor: Color {
        switch reviewPhase {
        case .noVersion, .replaced: return .secondary
        case .editable: return .gray
        case .inReview, .canceling, .releasing: return .orange
        case .pendingDeveloperRelease: return .blue
        case .live: return .green
        }
    }

    @ViewBuilder
    private var appStoreReviewPrimaryButton: some View {
        switch reviewPhase {
        case .editable:
            Button {
                Task { await viewModel.submitSelectedAppStoreReview() }
            } label: {
                appStoreReviewOperationLabel(title: isAppStoreReviewOperationRunning ? strings.submittingForReview : strings.submitForReview, systemImage: "paperplane.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitAppStoreReview)
        case .inReview:
            Button(role: .destructive) {
                showWithdrawConfirm = true
            } label: {
                appStoreReviewOperationLabel(title: isAppStoreReviewOperationRunning ? strings.withdrawingReview : strings.withdrawReview, systemImage: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isOperationRunning)
            .confirmationDialog(strings.withdrawReviewConfirm, isPresented: $showWithdrawConfirm) {
                Button(strings.withdrawReview, role: .destructive) { Task { await viewModel.cancelAppStoreReview() } }
                Button(strings.cancel, role: .cancel) {}
            }
        case .pendingDeveloperRelease:
            Button {
                showReleaseConfirm = true
            } label: {
                appStoreReviewOperationLabel(title: isAppStoreReviewOperationRunning ? strings.releasingToAppStore : strings.releaseToAppStore, systemImage: "checkmark.seal")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isOperationRunning)
            .confirmationDialog(strings.releaseNowConfirm, isPresented: $showReleaseConfirm) {
                Button(strings.releaseToAppStore) { Task { await viewModel.releaseApprovedVersion() } }
                Button(strings.cancel, role: .cancel) {}
            }
        case .noVersion, .canceling, .releasing, .live, .replaced:
            EmptyView()
        }
    }

    @ViewBuilder
    private func reviewReadinessView(_ snapshot: AppStoreReviewSnapshot) -> some View {
        let items = AppStoreReviewReadiness.evaluate(snapshot: snapshot)
        if reviewPhase == .editable {
            VStack(alignment: .leading, spacing: 4) {
                Text(strings.submissionReadiness)
                    .font(.callout.weight(.semibold))
                ForEach(items) { item in
                    HStack(spacing: 6) {
                        Image(systemName: readinessSymbol(item.severity))
                            .foregroundStyle(readinessColor(item.severity))
                        Text(readinessTitle(item.kind))
                            .font(.caption)
                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func readinessSymbol(_ severity: ReviewReadinessSeverity) -> String {
        switch severity {
        case .green: return "checkmark.circle.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .red: return "xmark.circle.fill"
        }
    }

    private func readinessColor(_ severity: ReviewReadinessSeverity) -> Color {
        switch severity {
        case .green: return .green
        case .yellow: return .orange
        case .red: return .red
        }
    }

    private func readinessTitle(_ kind: ReviewReadinessKind) -> String {
        switch kind {
        case .buildValid: return strings.readinessBuildValid
        case .whatsNewFilled: return strings.readinessWhatsNew
        case .reviewContactComplete: return strings.readinessContact
        case .screenshotsPresent: return strings.readinessScreenshots
        case .exportCompliance: return strings.readinessExport
        }
    }
```

- [ ] **Step 3: Update `canSubmitAppStoreReview`, add confirm state, remove obsolete members**

In `ProjectDetailView.swift`:

Change `canSubmitAppStoreReview` (line ~1052) to also require a green checklist:

```swift
    private var canSubmitAppStoreReview: Bool {
        guard let snapshot = appStoreReviewSnapshot, snapshot.selectedBuildID != nil else { return false }
        if viewModel.isOperationRunning { return false }
        return !AppStoreReviewReadiness.blocks(AppStoreReviewReadiness.evaluate(snapshot: snapshot))
    }
```

Add state properties alongside the other `@State` fields (e.g. near `showAdvancedStoreFields`):

```swift
    @State private var showWithdrawConfirm = false
    @State private var showReleaseConfirm = false
```

Delete the now-unused `canBindSelectedAppStoreBuild` computed property (lines ~1045-1050) — the standalone bind button is gone. Leave the `busy` sub-step label driven by `appStoreReviewOperationLabel` (unchanged), but update its title per phase by keeping the existing generic label; the phase-specific busy text is already carried by each primary button's `title:` argument.

> The old `appStoreReviewActions` referenced `strings.prepareStoreVersion`, `strings.bindSelectedBuild`, `strings.submitStoreReview`, and `strings.appStoreReviewSafeActionHint`. Those `AppStrings` entries may now be unused; leave them in place (removing them is out of scope and risks touching the prior slice's code).

- [ ] **Step 4: Add the release-strategy picker to the snapshot header**

In `appStoreReviewSnapshotView` (line ~551), replace the read-only `releaseStrategyBadge(snapshot.releaseType)` call inside the "Release strategy" column with an editable picker:

```swift
                    Picker(strings.releaseStrategy, selection: releaseTypeBinding) {
                        Text(strings.manualRelease).tag("MANUAL")
                        Text(strings.afterApprovalRelease).tag("AFTER_APPROVAL")
                        if snapshot.releaseType == "SCHEDULED" {
                            Text(strings.scheduledRelease).tag("SCHEDULED")
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180)
                    .disabled(viewModel.isOperationRunning || reviewPhase != .editable)
```

Add the binding near `appStoreBuildSelectionBinding` (line ~1038):

```swift
    private var releaseTypeBinding: Binding<String> {
        Binding(
            get: { appStoreReviewSnapshot?.releaseType ?? "MANUAL" },
            set: { newValue in Task { await viewModel.updateAppStoreReviewReleaseType(newValue) } }
        )
    }
```

- [ ] **Step 5: Build and verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Run the full test suite**

Run: `swift test`
Expected: all tests pass (Core is unchanged in behavior the tests assert; UI is not unit-tested).

- [ ] **Step 7: Launch the dev app and eyeball the new flow**

Package the current debug build into a proper `.app` bundle (a bare `swift run` executable renders blank on this machine) and open it:

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

Verify by eye: badge reflects phase; in `editable` the readiness list shows and Submit is disabled with red items until fixed; after submit the badge flips to In Review and the button becomes Withdraw; release-strategy picker switches Manual/After Approval.

- [ ] **Step 8: Commit**

```bash
git add Sources/ProjPostApp/Views/ProjectDetailView.swift Sources/ProjPostCore/Localization/AppStrings.swift
git commit -m "feat(ui): state-driven App Store review CTA, readiness checklist, release controls"
```

---

## Self-Review

- **Spec coverage:** phase model → Task 2; CTA state machine → Task 5; auto-bind → Task 3; read active submission → Task 1+3; withdraw → Task 1+4+5; release → Task 1+4+5; release-type editable → Task 1+4+5; readiness checklist → Task 2+5; multi-step feedback (phase-labelled busy button) → Task 5; reload-after-write → Task 3+4. Screenshots stay read-only (yellow) → Task 2. All covered.
- **Type consistency:** `AppStoreReviewPhase`, `ReviewReadinessItem`, `AppStoreReviewReadiness.evaluate/blocks`, `reviewSubmissionID`, and the four client methods are named identically across tasks and tests.
- **Fake conformance:** both `FakeAppStoreConnectClient` and `FakeASCClient` are updated in Task 1 so the suite compiles before later tasks depend on them.
