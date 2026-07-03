# TestFlight External Groups Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show TestFlight internal/external group readiness and let ProjPost automatically or manually link an approved build to all external groups and enable public links.

**Architecture:** Extend the existing App Store Connect client with one read method for build-associated beta groups, then add a focused TestFlight distribution state model in `ProjPostCore`. `AppViewModel` will compose app/build/group data into a snapshot, run best-effort external group linking when requested or when approval automation is enabled, and `ProjectDetailView` will render the snapshot and controls in the existing TestFlight section.

**Tech Stack:** Swift Package Manager, Swift concurrency, SwiftUI, XCTest, existing `AppStoreConnectClientProtocol`, existing project profile persistence.

## Global Constraints

- New project setting `autoLinkExternalGroupsAfterBetaApproval` defaults to `true`.
- Internal beta groups are displayed but never passed to public-link enablement.
- External group linking is best-effort per group; one failure must not stop the remaining groups.
- Distribution refresh and linking failures must not clear upload console history.
- UI controls must be disabled while upload, beta review, or distribution operations are running.
- Existing App Store Connect API authentication remains JWT from the saved `.p8` Keychain entry.
- No new third-party dependencies.

---

## File Structure

- Modify `Sources/ProjPostCore/Models/DomainModels.swift`
  - Add project persistence setting `autoLinkExternalGroupsAfterBetaApproval`.
  - Add `TestFlightDistributionState`, `TestFlightDistributionSnapshot`, `TestFlightDistributionGroup`, and `TestFlightDistributionGroupOperationState`.
- Modify `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`
  - Add `fetchBetaGroupsForBuild(buildID:)`.
  - Reuse existing `ASCBetaGroup` mapping.
- Modify `Sources/ProjPostCore/AppState/AppViewModel.swift`
  - Publish `testFlightDistributionState`.
  - Include distribution running state in `isOperationRunning`.
  - Add automation toggle mutation.
  - Extend refresh status to fetch groups and current-build associations.
  - Add manual `linkExternalGroupsForLatestBuild()`.
- Modify `Sources/ProjPostApp/Views/ProjectDetailView.swift`
  - Replace placeholder TestFlight rows with a distribution section.
  - Add automation toggle, internal/external group list, link button, and copyable links.
- Modify `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`
  - Add client test for build-associated groups endpoint.
- Modify `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`
  - Add distribution refresh, automation, manual linking, persistence, and partial failure tests.
- Modify `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`
  - Update fake client protocol conformance for the new method.
- Modify `docs/manual-test-checklist.md`
  - Replace TestFlight group automation “pending” notes with manual test steps.

---

### Task 1: Persist Project Automation Setting And Add Distribution Domain Types

**Files:**
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes: existing `ProjectProfile`, `ASCBetaGroup`, `ASCBuild`.
- Produces:
  - `ProjectProfile.autoLinkExternalGroupsAfterBetaApproval: Bool`
  - `TestFlightDistributionGroupOperationState`
  - `TestFlightDistributionGroup`
  - `TestFlightDistributionSnapshot`
  - `TestFlightDistributionState`

- [ ] **Step 1: Write failing persistence/default tests**

Add these tests near other project profile/view-model tests in `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`:

```swift
func testNewProjectsDefaultExternalGroupAutomationOn() {
    let project = makeProject(name: "Demo")

    XCTAssertTrue(project.autoLinkExternalGroupsAfterBetaApproval)
}

func testTogglingExternalGroupAutomationPersistsWithProject() {
    let project = makeProject(name: "Demo")
    let store = FakeProjectProfileStore()
    let viewModel = AppViewModel(
        store: store,
        accountStore: FakeAppleAccountProfileStore(),
        credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(),
        checkEngine: FakeConfigurationCheckEngine(),
        uploadRunner: FakeUploadJobRunner(),
        projects: [project]
    )

    viewModel.updateAutoLinkExternalGroupsAfterBetaApproval(false)

    XCTAssertEqual(viewModel.selectedProject?.autoLinkExternalGroupsAfterBetaApproval, false)
    XCTAssertEqual(store.savedProfiles.first?.autoLinkExternalGroupsAfterBetaApproval, false)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter AppViewModelStateTests/testNewProjectsDefaultExternalGroupAutomationOn --filter AppViewModelStateTests/testTogglingExternalGroupAutomationPersistsWithProject
```

Expected: fail because `ProjectProfile.autoLinkExternalGroupsAfterBetaApproval` and `AppViewModel.updateAutoLinkExternalGroupsAfterBetaApproval(_:)` do not exist.

- [ ] **Step 3: Add model fields and distribution types**

In `Sources/ProjPostCore/Models/DomainModels.swift`, add the stored setting to `ProjectProfile`:

```swift
public var autoLinkExternalGroupsAfterBetaApproval: Bool
```

Update `ProjectProfile.init` signature by adding this argument after `appliedSettings` with a default:

```swift
autoLinkExternalGroupsAfterBetaApproval: Bool = true
```

Assign it in the initializer:

```swift
self.autoLinkExternalGroupsAfterBetaApproval = autoLinkExternalGroupsAfterBetaApproval
```

At the end of `DomainModels.swift`, after `BetaReviewSubmissionState`, add:

```swift
public enum TestFlightDistributionGroupOperationState: Codable, Equatable {
    case idle
    case linked
    case failed(message: String)
}

public struct TestFlightDistributionGroup: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var isInternalGroup: Bool
    public var isCurrentBuildAssociated: Bool
    public var publicLinkEnabled: Bool
    public var publicLink: String?
    public var publicLinkLimit: Int?
    public var operationState: TestFlightDistributionGroupOperationState

    public init(
        id: String,
        name: String,
        isInternalGroup: Bool,
        isCurrentBuildAssociated: Bool,
        publicLinkEnabled: Bool,
        publicLink: String?,
        publicLinkLimit: Int?,
        operationState: TestFlightDistributionGroupOperationState = .idle
    ) {
        self.id = id
        self.name = name
        self.isInternalGroup = isInternalGroup
        self.isCurrentBuildAssociated = isCurrentBuildAssociated
        self.publicLinkEnabled = publicLinkEnabled
        self.publicLink = publicLink
        self.publicLinkLimit = publicLinkLimit
        self.operationState = operationState
    }
}

public struct TestFlightDistributionSnapshot: Codable, Equatable {
    public var appID: String
    public var buildID: String
    public var version: String
    public var buildNumber: String
    public var processingState: String?
    public var betaReviewState: String?
    public var betaReviewStateText: String
    public var internalGroups: [TestFlightDistributionGroup]
    public var externalGroups: [TestFlightDistributionGroup]

    public init(
        appID: String,
        buildID: String,
        version: String,
        buildNumber: String,
        processingState: String?,
        betaReviewState: String?,
        betaReviewStateText: String,
        internalGroups: [TestFlightDistributionGroup],
        externalGroups: [TestFlightDistributionGroup]
    ) {
        self.appID = appID
        self.buildID = buildID
        self.version = version
        self.buildNumber = buildNumber
        self.processingState = processingState
        self.betaReviewState = betaReviewState
        self.betaReviewStateText = betaReviewStateText
        self.internalGroups = internalGroups
        self.externalGroups = externalGroups
    }
}

public enum TestFlightDistributionState: Equatable {
    case idle
    case loading
    case loaded(TestFlightDistributionSnapshot)
    case linking(TestFlightDistributionSnapshot?)
    case failed(message: String)
}
```

- [ ] **Step 4: Add ViewModel setting mutation**

In `Sources/ProjPostCore/AppState/AppViewModel.swift`, add:

```swift
public func updateAutoLinkExternalGroupsAfterBetaApproval(_ value: Bool) {
    guard !isOperationRunning else { return }
    mutateSelectedProject(invalidateChecks: false) { project in
        project.autoLinkExternalGroupsAfterBetaApproval = value
    }
}
```

In `upsertProject(_:replacingSelectedProject:)`, preserve the existing setting when replacing or rescanning:

```swift
updated.autoLinkExternalGroupsAfterBetaApproval = projects[index].autoLinkExternalGroupsAfterBetaApproval
```

Add that assignment in both branches that currently preserve `selectedAccountID` and `lastUpload`.

- [ ] **Step 5: Run targeted tests**

Run:

```bash
swift test --filter AppViewModelStateTests/testNewProjectsDefaultExternalGroupAutomationOn --filter AppViewModelStateTests/testTogglingExternalGroupAutomationPersistsWithProject
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/Models/DomainModels.swift Sources/ProjPostCore/AppState/AppViewModel.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat: add TestFlight distribution models"
```

---

### Task 2: Add App Store Connect Read For Build-Associated Beta Groups

**Files:**
- Modify: `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`
- Modify: `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`
- Modify: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`
- Modify: `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`

**Interfaces:**
- Consumes: existing `ASCBetaGroup`.
- Produces:
  - `AppStoreConnectClientProtocol.fetchBetaGroupsForBuild(buildID:) async throws -> [ASCBetaGroup]`
  - Live implementation that calls `/v1/builds/{buildID}/betaGroups`.

- [ ] **Step 1: Write failing client test**

Add to `Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift`:

```swift
func testFetchBetaGroupsForBuildMapsAssociatedGroups() async throws {
    let transport = StubASCTransport(responses: [
        ASCTransportResponse(
            statusCode: 200,
            body: #"{"data":[{"id":"internal","type":"betaGroups","attributes":{"name":"内部测试","isInternalGroup":true,"publicLinkEnabled":false}},{"id":"external","type":"betaGroups","attributes":{"name":"外部测试 A","isInternalGroup":false,"publicLinkEnabled":true,"publicLink":"https://testflight.apple.com/join/abc","publicLinkLimit":50}}]}"#
        )
    ])
    let client = AppStoreConnectClient(jwtProvider: { "token" }, transport: transport)

    let groups = try await client.fetchBetaGroupsForBuild(buildID: "build-123")

    XCTAssertEqual(groups, [
        ASCBetaGroup(id: "internal", name: "内部测试", isInternalGroup: true, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil),
        ASCBetaGroup(id: "external", name: "外部测试 A", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/abc", publicLinkLimit: 50)
    ])
    XCTAssertEqual(transport.requests.first?.path, "/v1/builds/build-123/betaGroups")
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
swift test --filter AppStoreConnectClientTests/testFetchBetaGroupsForBuildMapsAssociatedGroups
```

Expected: fail because `fetchBetaGroupsForBuild(buildID:)` does not exist.

- [ ] **Step 3: Add protocol method and live implementation**

In `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`, add to `AppStoreConnectClientProtocol`:

```swift
func fetchBetaGroupsForBuild(buildID: String) async throws -> [ASCBetaGroup]
```

Add to `AppStoreConnectClient`:

```swift
public func fetchBetaGroupsForBuild(buildID: String) async throws -> [ASCBetaGroup] {
    let json = try await get(path: "/v1/builds/\(buildID)/betaGroups", query: [:])
    return try dataArray(from: json).map(Self.mapBetaGroup)
}
```

- [ ] **Step 4: Update fake protocol conformances**

In `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`, add storage to `FakeAppStoreConnectClient`:

```swift
var associatedBetaGroups: [ASCBetaGroup]
private(set) var fetchBetaGroupsForBuildIDs: [String] = []
```

Update its initializer:

```swift
associatedBetaGroups: [ASCBetaGroup] = [],
```

Assign:

```swift
self.associatedBetaGroups = associatedBetaGroups
```

Add method:

```swift
func fetchBetaGroupsForBuild(buildID: String) async throws -> [ASCBetaGroup] {
    fetchBetaGroupsForBuildIDs.append(buildID)
    return associatedBetaGroups
}
```

In `Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift`, add to its fake client:

```swift
func fetchBetaGroupsForBuild(buildID: String) async throws -> [ASCBetaGroup] { [] }
```

- [ ] **Step 5: Run targeted tests**

Run:

```bash
swift test --filter AppStoreConnectClientTests/testFetchBetaGroupsForBuildMapsAssociatedGroups
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift Tests/ProjPostCoreTests/AppStoreConnectClientTests.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift Tests/ProjPostCoreTests/ConfigurationCheckEngineTests.swift
git commit -m "feat: read TestFlight groups for build"
```

---

### Task 3: Refresh Distribution Snapshot Without Clearing Upload Console

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes:
  - `AppStoreConnectClientProtocol.fetchApp(bundleID:)`
  - `fetchBuilds(appID:appVersion:buildNumber:)`
  - `fetchBetaGroups(appID:)`
  - `fetchBetaGroupsForBuild(buildID:)`
- Produces:
  - `@Published public var testFlightDistributionState: TestFlightDistributionState`
  - `public func refreshLatestBuildTestFlightStatus() async` also populates distribution snapshot.

- [ ] **Step 1: Write failing refresh snapshot test**

Add to `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`:

```swift
func testRefreshLatestBuildTestFlightStatusLoadsDistributionGroupsWithoutClearingConsole() async {
    let account = AppleAccountProfile(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        displayName: "Company",
        keyID: "KEY1234567",
        issuerID: "issuer",
        teamID: "TEAM123",
        lastVerifiedAt: nil
    )
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let allGroups = [
        ASCBetaGroup(id: "internal", name: "内部测试", isInternalGroup: true, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil),
        ASCBetaGroup(id: "external-a", name: "外部测试 A", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/a", publicLinkLimit: 100),
        ASCBetaGroup(id: "external-b", name: "外部测试 B", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil)
    ]
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "WAITING_FOR_REVIEW")],
        betaGroups: allGroups,
        associatedBetaGroups: [allGroups[0], allGroups[1]]
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(),
        accountStore: FakeAppleAccountProfileStore(),
        credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(),
        checkEngine: FakeConfigurationCheckEngine(),
        uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect,
        projects: [project],
        accountProfiles: [account]
    )
    viewModel.uploadEvents = [UploadEvent(step: .upload, message: "Previous upload log", succeeded: true)]

    await viewModel.refreshLatestBuildTestFlightStatus()

    XCTAssertEqual(viewModel.uploadEvents, [UploadEvent(step: .upload, message: "Previous upload log", succeeded: true)])
    XCTAssertEqual(appStoreConnect.fetchBetaGroupsForBuildIDs, ["build-123"])
    guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
        return XCTFail("Expected loaded distribution snapshot")
    }
    XCTAssertEqual(snapshot.betaReviewStateText, "Waiting for Review")
    XCTAssertEqual(snapshot.internalGroups.map(\.name), ["内部测试"])
    XCTAssertEqual(snapshot.externalGroups.map(\.name), ["外部测试 A", "外部测试 B"])
    XCTAssertEqual(snapshot.externalGroups.map(\.isCurrentBuildAssociated), [true, false])
    XCTAssertEqual(snapshot.externalGroups.first?.publicLink, "https://testflight.apple.com/join/a")
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
swift test --filter AppViewModelStateTests/testRefreshLatestBuildTestFlightStatusLoadsDistributionGroupsWithoutClearingConsole
```

Expected: fail because `testFlightDistributionState` does not exist.

- [ ] **Step 3: Publish distribution state and running guard**

In `AppViewModel`, add property near `betaReviewState`:

```swift
@Published public var testFlightDistributionState: TestFlightDistributionState
```

Initialize in `init`:

```swift
self.testFlightDistributionState = .idle
```

Update `isOperationRunning`:

```swift
if case .loading = testFlightDistributionState {
    return true
}
if case .linking = testFlightDistributionState {
    return true
}
```

Update `clearRunState()` to include:

```swift
testFlightDistributionState = .idle
```

- [ ] **Step 4: Add snapshot builder helpers**

In `AppViewModel`, add private helper:

```swift
private static func distributionGroup(from group: ASCBetaGroup, associatedGroupIDs: Set<String>) -> TestFlightDistributionGroup {
    TestFlightDistributionGroup(
        id: group.id,
        name: group.name,
        isInternalGroup: group.isInternalGroup,
        isCurrentBuildAssociated: associatedGroupIDs.contains(group.id),
        publicLinkEnabled: group.publicLinkEnabled,
        publicLink: group.publicLink,
        publicLinkLimit: group.publicLinkLimit
    )
}
```

Add private async resolver:

```swift
private func loadLatestBuildDistribution(
    project: ProjectProfile,
    account: AppleAccountProfile
) async throws -> (snapshot: TestFlightDistributionSnapshot, build: ASCBuild, client: AppStoreConnectClientProtocol) {
    guard let bundleID = project.bundleID, !bundleID.isEmpty,
          let version = project.version, !version.isEmpty,
          let buildNumber = project.buildNumber, !buildNumber.isEmpty else {
        throw TestFlightDistributionError.missingProjectFields
    }

    let client = appStoreConnectClient(for: account)
    guard let app = try await client.fetchApp(bundleID: bundleID) else {
        throw TestFlightDistributionError.appNotFound(bundleID)
    }
    guard let build = try await client.fetchBuilds(appID: app.id, appVersion: version, buildNumber: buildNumber).first else {
        throw TestFlightDistributionError.buildNotFound(version: version, buildNumber: buildNumber)
    }

    let allGroups = try await client.fetchBetaGroups(appID: app.id)
    let associatedGroups = try await client.fetchBetaGroupsForBuild(buildID: build.id)
    let associatedIDs = Set(associatedGroups.map(\.id))
    let groups = allGroups.map { Self.distributionGroup(from: $0, associatedGroupIDs: associatedIDs) }
    let internalGroups = groups.filter(\.isInternalGroup).sorted { $0.name < $1.name }
    let externalGroups = groups.filter { !$0.isInternalGroup }.sorted { $0.name < $1.name }
    let reviewStateText = Self.readableBetaReviewState(build.betaReviewState) ?? "Not Submitted"

    return (
        TestFlightDistributionSnapshot(
            appID: app.id,
            buildID: build.id,
            version: version,
            buildNumber: buildNumber,
            processingState: build.processingState,
            betaReviewState: build.betaReviewState,
            betaReviewStateText: reviewStateText,
            internalGroups: internalGroups,
            externalGroups: externalGroups
        ),
        build,
        client
    )
}
```

Add a private error enum near other app-state helpers:

```swift
private enum TestFlightDistributionError: Error, Equatable {
    case missingProjectFields
    case appNotFound(String)
    case buildNotFound(version: String, buildNumber: String)
}
```

Add readable messages:

```swift
private static func testFlightDistributionErrorMessage(_ error: Error) -> String {
    switch error {
    case TestFlightDistributionError.missingProjectFields:
        return "Bundle ID, version, and build number are required before refreshing TestFlight distribution."
    case let TestFlightDistributionError.appNotFound(bundleID):
        return "App Store Connect app not found for \(bundleID)."
    case let TestFlightDistributionError.buildNotFound(version, buildNumber):
        return "Uploaded build \(version) (\(buildNumber)) was not found in App Store Connect yet."
    default:
        return "Refresh TestFlight distribution failed: \(error)"
    }
}
```

- [ ] **Step 5: Integrate refresh method**

Replace the body of `refreshLatestBuildTestFlightStatus()` after project/account guards with:

```swift
betaReviewState = .running
testFlightDistributionState = .loading
do {
    let loaded = try await loadLatestBuildDistribution(project: project, account: account)
    let snapshot = loaded.snapshot
    if let processingState = snapshot.processingState, processingState != "VALID" {
        betaReviewState = .succeeded(message: "TestFlight status: \(snapshot.betaReviewStateText). Build processing: \(processingState)")
    } else {
        betaReviewState = .succeeded(message: "TestFlight status: \(snapshot.betaReviewStateText)")
    }
    testFlightDistributionState = .loaded(snapshot)
} catch {
    let message = Self.testFlightDistributionErrorMessage(error)
    betaReviewState = .failed(message: message)
    testFlightDistributionState = .failed(message: message)
}
```

- [ ] **Step 6: Run targeted test**

Run:

```bash
swift test --filter AppViewModelStateTests/testRefreshLatestBuildTestFlightStatusLoadsDistributionGroupsWithoutClearingConsole
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat: load TestFlight distribution state"
```

---

### Task 4: Implement Automatic And Manual External Group Linking

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Test: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Consumes:
  - `TestFlightDistributionSnapshot`
  - `AppStoreConnectClientProtocol.addBuild(_:toBetaGroup:)`
  - `AppStoreConnectClientProtocol.enablePublicLink(betaGroupID:limit:)`
- Produces:
  - `public func linkExternalGroupsForLatestBuild() async`
  - Automatic linking inside `refreshLatestBuildTestFlightStatus()` when selected project setting is true and `build.betaReviewState == "APPROVED"`.

- [ ] **Step 1: Expand fake client for link tracking and failures**

In `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`, update `FakeAppStoreConnectClient`:

```swift
var addBuildFailuresByGroupID: [String: Error] = [:]
var enablePublicLinkFailuresByGroupID: [String: Error] = [:]
private(set) var addedBuildsToGroups: [(buildID: String, betaGroupID: String)] = []
private(set) var enabledPublicLinks: [(betaGroupID: String, limit: Int?)] = []
```

Replace `addBuild`:

```swift
func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {
    addedBuildsToGroups.append((buildID, betaGroupID))
    if let error = addBuildFailuresByGroupID[betaGroupID] {
        throw error
    }
}
```

Replace `enablePublicLink`:

```swift
func enablePublicLink(betaGroupID: String, limit: Int?) async throws -> ASCBetaGroup {
    enabledPublicLinks.append((betaGroupID, limit))
    if let error = enablePublicLinkFailuresByGroupID[betaGroupID] {
        throw error
    }
    return ASCBetaGroup(
        id: betaGroupID,
        name: betaGroups.first(where: { $0.id == betaGroupID })?.name ?? "External",
        isInternalGroup: false,
        publicLinkEnabled: true,
        publicLink: "https://testflight.apple.com/join/\(betaGroupID)",
        publicLinkLimit: limit
    )
}
```

- [ ] **Step 2: Write failing automation test**

Add:

```swift
func testApprovedBuildAutoLinksExternalGroupsAndEnablesPublicLinks() async {
    let account = AppleAccountProfile(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        displayName: "Company",
        keyID: "KEY1234567",
        issuerID: "issuer",
        teamID: "TEAM123",
        lastVerifiedAt: nil
    )
    let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    let allGroups = [
        ASCBetaGroup(id: "internal", name: "内部测试", isInternalGroup: true, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil),
        ASCBetaGroup(id: "external-a", name: "外部测试 A", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: 100),
        ASCBetaGroup(id: "external-b", name: "外部测试 B", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/b", publicLinkLimit: nil)
    ]
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED")],
        betaGroups: allGroups,
        associatedBetaGroups: [allGroups[2]]
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(),
        accountStore: FakeAppleAccountProfileStore(),
        credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(),
        checkEngine: FakeConfigurationCheckEngine(),
        uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect,
        projects: [project],
        accountProfiles: [account]
    )

    await viewModel.refreshLatestBuildTestFlightStatus()

    XCTAssertEqual(appStoreConnect.addedBuildsToGroups.map(\.betaGroupID), ["external-a"])
    XCTAssertEqual(appStoreConnect.enabledPublicLinks.map(\.betaGroupID), ["external-a"])
    guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
        return XCTFail("Expected loaded snapshot after automation")
    }
    XCTAssertEqual(snapshot.externalGroups.map(\.isCurrentBuildAssociated), [true, true])
    XCTAssertEqual(snapshot.externalGroups.map(\.publicLinkEnabled), [true, true])
}
```

- [ ] **Step 3: Write failing disabled automation test**

Add:

```swift
func testApprovedBuildDoesNotAutoLinkWhenAutomationDisabled() async {
    let account = AppleAccountProfile(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        displayName: "Company",
        keyID: "KEY1234567",
        issuerID: "issuer",
        teamID: "TEAM123",
        lastVerifiedAt: nil
    )
    var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    project.autoLinkExternalGroupsAfterBetaApproval = false
    let external = ASCBetaGroup(id: "external", name: "外部测试", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED")],
        betaGroups: [external],
        associatedBetaGroups: []
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(),
        accountStore: FakeAppleAccountProfileStore(),
        credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(),
        checkEngine: FakeConfigurationCheckEngine(),
        uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect,
        projects: [project],
        accountProfiles: [account]
    )

    await viewModel.refreshLatestBuildTestFlightStatus()

    XCTAssertTrue(appStoreConnect.addedBuildsToGroups.isEmpty)
    XCTAssertTrue(appStoreConnect.enabledPublicLinks.isEmpty)
    guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
        return XCTFail("Expected loaded snapshot")
    }
    XCTAssertEqual(snapshot.externalGroups.first?.isCurrentBuildAssociated, false)
}
```

- [ ] **Step 4: Write failing manual and partial failure tests**

Add:

```swift
func testManualLinkExternalGroupsLinksAllExternalGroupsOnly() async {
    let account = AppleAccountProfile(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        displayName: "Company",
        keyID: "KEY1234567",
        issuerID: "issuer",
        teamID: "TEAM123",
        lastVerifiedAt: nil
    )
    var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    project.autoLinkExternalGroupsAfterBetaApproval = false
    let internalGroup = ASCBetaGroup(id: "internal", name: "内部测试", isInternalGroup: true, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil)
    let externalGroup = ASCBetaGroup(id: "external", name: "外部测试", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil)
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED")],
        betaGroups: [internalGroup, externalGroup],
        associatedBetaGroups: []
    )
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(),
        accountStore: FakeAppleAccountProfileStore(),
        credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(),
        checkEngine: FakeConfigurationCheckEngine(),
        uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect,
        projects: [project],
        accountProfiles: [account]
    )

    await viewModel.linkExternalGroupsForLatestBuild()

    XCTAssertEqual(appStoreConnect.addedBuildsToGroups.map(\.betaGroupID), ["external"])
    XCTAssertEqual(appStoreConnect.enabledPublicLinks.map(\.betaGroupID), ["external"])
}

func testManualLinkExternalGroupsCapturesPartialFailures() async {
    let account = AppleAccountProfile(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        displayName: "Company",
        keyID: "KEY1234567",
        issuerID: "issuer",
        teamID: "TEAM123",
        lastVerifiedAt: nil
    )
    var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
    project.autoLinkExternalGroupsAfterBetaApproval = false
    let groups = [
        ASCBetaGroup(id: "external-a", name: "外部测试 A", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil),
        ASCBetaGroup(id: "external-b", name: "外部测试 B", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil)
    ]
    let appStoreConnect = FakeAppStoreConnectClient(
        app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
        builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED")],
        betaGroups: groups,
        associatedBetaGroups: []
    )
    appStoreConnect.enablePublicLinkFailuresByGroupID = ["external-b": TestError.unavailable]
    let viewModel = AppViewModel(
        store: FakeProjectProfileStore(),
        accountStore: FakeAppleAccountProfileStore(),
        credentialVault: FakeCredentialVault(),
        scanner: FakeProjectScanner(),
        checkEngine: FakeConfigurationCheckEngine(),
        uploadRunner: FakeUploadJobRunner(),
        appStoreConnectClient: appStoreConnect,
        projects: [project],
        accountProfiles: [account]
    )

    await viewModel.linkExternalGroupsForLatestBuild()

    XCTAssertEqual(appStoreConnect.addedBuildsToGroups.map(\.betaGroupID), ["external-a", "external-b"])
    XCTAssertEqual(appStoreConnect.enabledPublicLinks.map(\.betaGroupID), ["external-a", "external-b"])
    guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
        return XCTFail("Expected loaded snapshot")
    }
    XCTAssertEqual(snapshot.externalGroups.first(where: { $0.id == "external-a" })?.operationState, .linked)
    if case let .failed(message) = snapshot.externalGroups.first(where: { $0.id == "external-b" })?.operationState {
        XCTAssertTrue(message.contains("unavailable"))
    } else {
        XCTFail("Expected failed operation state for external-b")
    }
    XCTAssertEqual(viewModel.betaReviewState, .failed(message: "Linked external groups with 1 failure."))
}
```

- [ ] **Step 5: Run tests to verify failure**

Run:

```bash
swift test --filter AppViewModelStateTests/testApprovedBuildAutoLinksExternalGroupsAndEnablesPublicLinks --filter AppViewModelStateTests/testApprovedBuildDoesNotAutoLinkWhenAutomationDisabled --filter AppViewModelStateTests/testManualLinkExternalGroupsLinksAllExternalGroupsOnly --filter AppViewModelStateTests/testManualLinkExternalGroupsCapturesPartialFailures
```

Expected: fail because linking logic does not exist.

- [ ] **Step 6: Implement link operation helpers**

In `AppViewModel`, add:

```swift
public func linkExternalGroupsForLatestBuild() async {
    guard !isOperationRunning else { return }
    guard let project = selectedProject else {
        testFlightDistributionState = .failed(message: "Select a project before linking external groups.")
        return
    }
    guard let account = accountProfile else {
        testFlightDistributionState = .failed(message: "Select an Apple account before linking external groups.")
        return
    }

    testFlightDistributionState = .linking(currentDistributionSnapshot)
    do {
        let loaded = try await loadLatestBuildDistribution(project: project, account: account)
        let linkedSnapshot = await linkExternalGroups(snapshot: loaded.snapshot, client: loaded.client)
        testFlightDistributionState = .loaded(linkedSnapshot.snapshot)
        betaReviewState = linkedSnapshot.failureCount == 0
            ? .succeeded(message: "External TestFlight groups linked.")
            : .failed(message: "Linked external groups with \(linkedSnapshot.failureCount) failure.")
    } catch {
        let message = Self.testFlightDistributionErrorMessage(error)
        testFlightDistributionState = .failed(message: message)
        betaReviewState = .failed(message: message)
    }
}

private var currentDistributionSnapshot: TestFlightDistributionSnapshot? {
    switch testFlightDistributionState {
    case .loaded(let snapshot), .linking(let snapshot?):
        return snapshot
    default:
        return nil
    }
}

private func linkExternalGroups(
    snapshot: TestFlightDistributionSnapshot,
    client: AppStoreConnectClientProtocol
) async -> (snapshot: TestFlightDistributionSnapshot, failureCount: Int) {
    var updated = snapshot
    var failureCount = 0
    var linkedGroups: [TestFlightDistributionGroup] = []

    for group in snapshot.externalGroups {
        var updatedGroup = group
        do {
            if !group.isCurrentBuildAssociated {
                try await client.addBuild(snapshot.buildID, toBetaGroup: group.id)
                updatedGroup.isCurrentBuildAssociated = true
            }
            if !group.publicLinkEnabled {
                let enabled = try await client.enablePublicLink(betaGroupID: group.id, limit: group.publicLinkLimit)
                updatedGroup.publicLinkEnabled = enabled.publicLinkEnabled
                updatedGroup.publicLink = enabled.publicLink
                updatedGroup.publicLinkLimit = enabled.publicLinkLimit
            }
            updatedGroup.operationState = .linked
        } catch {
            failureCount += 1
            updatedGroup.operationState = .failed(message: "\(error)")
        }
        linkedGroups.append(updatedGroup)
    }

    updated.externalGroups = linkedGroups
    return (updated, failureCount)
}
```

- [ ] **Step 7: Add automatic linking after approved refresh**

In `refreshLatestBuildTestFlightStatus()`, after building the snapshot but before setting `.loaded`, add:

```swift
var finalSnapshot = snapshot
var linkFailureCount = 0
if project.autoLinkExternalGroupsAfterBetaApproval,
   snapshot.betaReviewState == "APPROVED",
   !snapshot.externalGroups.isEmpty {
    testFlightDistributionState = .linking(snapshot)
    let result = await linkExternalGroups(snapshot: snapshot, client: loaded.client)
    finalSnapshot = result.snapshot
    linkFailureCount = result.failureCount
}
testFlightDistributionState = .loaded(finalSnapshot)
if linkFailureCount > 0 {
    betaReviewState = .failed(message: "Linked external groups with \(linkFailureCount) failure.")
}
```

Keep the existing review-state success message when `linkFailureCount == 0`.

- [ ] **Step 8: Run targeted tests**

Run:

```bash
swift test --filter AppViewModelStateTests/testApprovedBuildAutoLinksExternalGroupsAndEnablesPublicLinks --filter AppViewModelStateTests/testApprovedBuildDoesNotAutoLinkWhenAutomationDisabled --filter AppViewModelStateTests/testManualLinkExternalGroupsLinksAllExternalGroupsOnly --filter AppViewModelStateTests/testManualLinkExternalGroupsCapturesPartialFailures
```

Expected: pass.

- [ ] **Step 9: Commit**

```bash
git add Sources/ProjPostCore/AppState/AppViewModel.swift Tests/ProjPostCoreTests/AppViewModelStateTests.swift
git commit -m "feat: link external TestFlight groups"
```

---

### Task 5: Replace Placeholder UI With TestFlight Distribution Controls

**Files:**
- Modify: `Sources/ProjPostApp/Views/ProjectDetailView.swift`

**Interfaces:**
- Consumes:
  - `viewModel.testFlightDistributionState`
  - `viewModel.selectedProject?.autoLinkExternalGroupsAfterBetaApproval`
  - `viewModel.updateAutoLinkExternalGroupsAfterBetaApproval(_:)`
  - `viewModel.linkExternalGroupsForLatestBuild()`
- Produces:
  - Visible internal/external group status rows.
  - Toggle for approved-build automation.
  - Manual link action.

- [ ] **Step 1: Add automation toggle binding**

In `ProjectDetailView`, add:

```swift
private var autoLinkExternalGroupsBinding: Binding<Bool> {
    Binding(
        get: { viewModel.selectedProject?.autoLinkExternalGroupsAfterBetaApproval ?? true },
        set: { viewModel.updateAutoLinkExternalGroupsAfterBetaApproval($0) }
    )
}
```

- [ ] **Step 2: Replace placeholder rows**

Replace:

```swift
VStack(alignment: .leading, spacing: 8) {
    placeholderRow(title: "Internal testers", value: "Available after the next successful upload")
    placeholderRow(title: "Public TestFlight link", value: "Create a public link after Apple finishes processing")
}
```

with:

```swift
distributionSection
```

- [ ] **Step 3: Add distribution section view**

Add this inside `ProjectDetailView`:

```swift
private var distributionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
        Toggle("Auto link approved build to external groups", isOn: autoLinkExternalGroupsBinding)
            .disabled(viewModel.isOperationRunning)

        switch viewModel.testFlightDistributionState {
        case .idle:
            placeholderRow(title: "TestFlight Distribution", value: "Refresh TF Status to load tester groups.")
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading TestFlight groups...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .linking(let snapshot):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Linking external TestFlight groups...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let snapshot {
                    distributionSnapshotView(snapshot)
                }
            }
        case .loaded(let snapshot):
            distributionSnapshotView(snapshot)
        case .failed(let message):
            placeholderRow(title: "TestFlight Distribution", value: message)
        }
    }
}
```

- [ ] **Step 4: Add snapshot and group row views**

Add:

```swift
private func distributionSnapshotView(_ snapshot: TestFlightDistributionSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            placeholderRow(
                title: "Current build",
                value: "\(snapshot.version) (\(snapshot.buildNumber)) · \(snapshot.betaReviewStateText)"
            )
            Spacer()
            Button {
                Task {
                    await viewModel.linkExternalGroupsForLatestBuild()
                }
            } label: {
                Label("Link External Groups", systemImage: "link")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isOperationRunning || snapshot.externalGroups.isEmpty)
        }

        if !snapshot.internalGroups.isEmpty {
            Text("Internal Testing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(snapshot.internalGroups) { group in
                distributionGroupRow(group)
            }
        }

        Text("External Testing")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

        if snapshot.externalGroups.isEmpty {
            placeholderRow(title: "External groups", value: "No external TestFlight groups found.")
        } else {
            ForEach(snapshot.externalGroups) { group in
                distributionGroupRow(group)
            }
        }
    }
}

private func distributionGroupRow(_ group: TestFlightDistributionGroup) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Image(systemName: group.isCurrentBuildAssociated ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(group.isCurrentBuildAssociated ? .green : .secondary)
            Text(group.name)
                .font(.callout.weight(.medium))
            Spacer()
            Text(group.publicLinkEnabled ? "Link On" : "Link Off")
                .font(.caption)
                .foregroundStyle(group.publicLinkEnabled ? .green : .secondary)
        }

        if let publicLink = group.publicLink, !publicLink.isEmpty {
            Text(publicLink)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .foregroundStyle(.blue)
        } else if !group.isInternalGroup {
            Text(group.publicLinkEnabled ? "Public link pending from Apple." : "Public link not enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        switch group.operationState {
        case .idle:
            EmptyView()
        case .linked:
            Text("Linked")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
    .padding(.vertical, 4)
}
```

- [ ] **Step 5: Build to catch SwiftUI type errors**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/ProjPostApp/Views/ProjectDetailView.swift
git commit -m "feat: show TestFlight distribution groups"
```

---

### Task 6: Documentation, Full Verification, Package, And Restart

**Files:**
- Modify: `docs/manual-test-checklist.md`

**Interfaces:**
- Consumes: completed core and UI implementation.
- Produces: updated manual verification steps and packaged app.

- [ ] **Step 1: Update manual checklist**

In `docs/manual-test-checklist.md`, replace the old TestFlight pending automation notes with:

```markdown
## TestFlight 外部测试组自动化

- [ ] 点击 `Refresh TF Status`
- [ ] 确认 `Internal Testing` 显示内部测试组
- [ ] 确认 `External Testing` 显示所有外部测试组
- [ ] 确认两个外部测试组显示各自 public link 或 pending 状态
- [ ] 保持 `Auto link approved build to external groups` 打开，等待/刷新到 `Approved` 后确认 app 自动关联所有外部组
- [ ] 关闭自动开关，点击 `Link External Groups`，确认无需打开网页即可关联外部测试组并启用 public link
- [ ] 确认失败的外部组会单独显示错误，成功的外部组链接仍保留
```

- [ ] **Step 2: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass with 0 failures.

- [ ] **Step 3: Run build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 4: Package app**

Run:

```bash
bash -n scripts/package_app.sh && scripts/package_app.sh
```

Expected: output includes:

```text
Packaged /Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost/dist/ProjPost.app
```

- [ ] **Step 5: Restart packaged app**

Run:

```bash
pkill -x ProjPostApp || true
sleep 1
open /Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost/dist/ProjPost.app
sleep 2
pgrep -fl ProjPostApp
```

Expected: one running `ProjPostApp` process under `dist/ProjPost.app`.

- [ ] **Step 6: Check diff cleanliness**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 7: Final commit**

```bash
git add docs/manual-test-checklist.md
git commit -m "docs: update TestFlight group manual checks"
```

---

## Self-Review Notes

- Spec coverage: the plan covers default-on automation, manual override, internal/external group display, public link enablement, build-associated group reads, partial failure handling, persistence, and manual verification.
- Scope: the plan does not implement store release review or invite management; it only covers TestFlight beta groups and links.
- Type consistency: all new public names are defined before use: `fetchBetaGroupsForBuild(buildID:)`, `testFlightDistributionState`, `updateAutoLinkExternalGroupsAfterBetaApproval(_:)`, and `linkExternalGroupsForLatestBuild()`.
