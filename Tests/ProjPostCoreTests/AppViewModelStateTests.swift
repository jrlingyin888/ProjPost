import XCTest
@testable import ProjPostCore

final class AppViewModelStateTests: XCTestCase {
    func testSelectingProjectUpdatesSelectedProject() {
        let first = makeProject(name: "First")
        let second = makeProject(name: "Second")
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [first, second]
        )

        viewModel.selectProject(second.id)

        XCTAssertEqual(viewModel.selectedProject?.id, second.id)
    }

    func testLoadProjectsReplacesProjectsAndSelectsFirst() throws {
        let loaded = [makeProject(name: "Loaded A"), makeProject(name: "Loaded B")]
        let store = FakeProjectProfileStore(loadResult: loaded)
        let viewModel = AppViewModel(
            store: store,
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner()
        )

        try viewModel.loadProjects()

        XCTAssertEqual(viewModel.projects, loaded)
        XCTAssertEqual(viewModel.selectedProject?.id, loaded[0].id)
    }

    func testSaveProjectsPersistsCurrentProjects() throws {
        let project = makeProject(name: "Saved")
        let store = FakeProjectProfileStore()
        let accountStore = FakeAppleAccountProfileStore()
        let viewModel = AppViewModel(
            store: store,
            accountStore: accountStore,
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [project]
        )

        try viewModel.saveProjects()

        XCTAssertEqual(store.savedProfiles, [project])
        XCTAssertEqual(accountStore.savedProfiles, [])
    }

    func testNewProjectsDefaultExternalGroupAutomationOff() {
        let project = makeProject(name: "Demo")

        XCTAssertFalse(project.autoLinkExternalGroupsAfterBetaApproval)
        XCTAssertEqual(project.autoLinkExternalGroupIDsAfterBetaApproval, [])
    }

    func testCheckForUpdatesPublishesAvailableRelease() async {
        let release = AppReleaseInfo(
            version: "1.1.0",
            tagName: "v1.1.0",
            name: "JJPost v1.1.0",
            releaseURL: URL(string: "https://github.com/jrlingyin888/ProjPost/releases/tag/v1.1.0")!,
            assetDownloadURL: nil
        )
        let updateChecker = FakeAppUpdateChecker(result: .available(currentVersion: "1.0.0", latestRelease: release))
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            updateChecker: updateChecker
        )

        await viewModel.checkForUpdatesIfNeeded()

        XCTAssertEqual(updateChecker.checkCallCount, 1)
        XCTAssertEqual(viewModel.updateState, .available(currentVersion: "1.0.0", latestRelease: release))
        XCTAssertEqual(viewModel.availableUpdate, release)
    }

    func testCheckForUpdatesStaysIdleWhenAppIsUpToDate() async {
        let updateChecker = FakeAppUpdateChecker(result: .upToDate(currentVersion: "1.1.0", latestVersion: "1.1.0"))
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            updateChecker: updateChecker
        )

        await viewModel.checkForUpdatesIfNeeded()

        XCTAssertEqual(updateChecker.checkCallCount, 1)
        XCTAssertEqual(viewModel.updateState, .idle)
        XCTAssertNil(viewModel.availableUpdate)
    }

    func testCheckForUpdatesFailureStaysIdleAndDoesNotBlockApp() async {
        let updateChecker = FakeAppUpdateChecker(error: TestError.unavailable)
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            updateChecker: updateChecker
        )

        await viewModel.checkForUpdatesIfNeeded()

        XCTAssertEqual(updateChecker.checkCallCount, 1)
        XCTAssertEqual(viewModel.updateState, .idle)
        XCTAssertEqual(viewModel.uploadState, .idle)
    }

    func testTogglingExternalGroupAutomationPersistsGroupSelectionWithProject() {
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

        viewModel.updateAutoLinkExternalGroup("external-a", isEnabled: true)
        viewModel.updateAutoLinkExternalGroup("external-b", isEnabled: true)
        viewModel.updateAutoLinkExternalGroup("external-a", isEnabled: false)

        XCTAssertEqual(viewModel.selectedProject?.autoLinkExternalGroupsAfterBetaApproval, false)
        XCTAssertEqual(viewModel.selectedProject?.autoLinkExternalGroupIDsAfterBetaApproval, ["external-b"])
        XCTAssertEqual(store.savedProfiles.first?.autoLinkExternalGroupIDsAfterBetaApproval, ["external-b"])
    }

    func testSaveAccountProfilePersistsAccountAndSelectedProjectReferenceImmediately() throws {
        let project = makeProject(name: "Demo")
        let store = FakeProjectProfileStore()
        let accountStore = FakeAppleAccountProfileStore()
        let viewModel = AppViewModel(
            store: store,
            accountStore: accountStore,
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [project]
        )

        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123")
        viewModel.saveAccountProfile()

        let savedAccount = try XCTUnwrap(viewModel.accountProfile)
        XCTAssertEqual(accountStore.savedProfiles, [savedAccount])
        XCTAssertEqual(store.savedProfiles.first?.selectedAccountID, savedAccount.id)
    }

    func testSavingCurrentDraftAccountPreservesChecksAndUploadConsoleState() async {
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1")
        let results = [CheckResult(id: "build-number", title: "Build Number 可用", message: "1.2.6 (1)", severity: .green)]
        let events = [UploadEvent(step: .upload, message: "Uploading archive", succeeded: true)]
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(results: results),
            uploadRunner: FakeUploadJobRunner(events: events),
            projects: [project]
        )

        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123")
        await viewModel.startUpload()

        viewModel.saveAccountProfile()

        XCTAssertEqual(viewModel.checkResults, results)
        XCTAssertEqual(viewModel.uploadEvents.count, 2)
        XCTAssertEqual(viewModel.uploadEvents.first?.step, .checkBundleAndApp)
        XCTAssertEqual(viewModel.uploadEvents.first?.message, "[OK] Build Number 可用\n1.2.6 (1)")
        XCTAssertEqual(Array(viewModel.uploadEvents.dropFirst()), events)
        XCTAssertTrue(viewModel.checksAreCurrent)
        XCTAssertEqual(viewModel.uploadState, .succeeded(message: "Upload finished successfully."))
    }

    func testProjectWorkbenchEditsAutosaveProfile() {
        let project = makeProject(name: "Demo", version: "1.2.5", buildNumber: "1")
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

        viewModel.updateSelectedProjectVersion("1.2.6")

        XCTAssertEqual(store.savedProfiles.first?.version, "1.2.6")
        XCTAssertEqual(store.loadResult.first?.version, "1.2.6")
    }

    func testFailedUploadSummaryAutosavesForNextLaunch() async {
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1")
        let store = FakeProjectProfileStore()
        let viewModel = AppViewModel(
            store: store,
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(error: TestError.unavailable),
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123")

        await viewModel.startUpload()

        XCTAssertEqual(store.savedProfiles.first?.lastUpload?.succeeded, false)
        XCTAssertEqual(store.loadResult.first?.lastUpload?.succeeded, false)
    }

    func testSubmitLatestBuildForBetaReviewUsesCurrentVersionBuild() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        project.lastUpload = UploadSummary(version: "1.2.6", buildNumber: "1", uploadedAt: Date(), succeeded: true, message: "Upload finished successfully.")
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID")],
            submission: ASCBetaReviewSubmission(id: "submission-123", betaReviewState: "IN_REVIEW")
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

        await viewModel.submitLatestBuildForBetaReview()

        XCTAssertEqual(appStoreConnect.fetchAppBundleIDs, ["com.example.demo"])
        XCTAssertEqual(appStoreConnect.fetchBuildRequests, [
            FakeAppStoreConnectClient.FetchBuildRequest(appID: "app-123", appVersion: "1.2.6", buildNumber: "1")
        ])
        XCTAssertEqual(appStoreConnect.submittedBuildIDs, ["build-123"])
        XCTAssertEqual(viewModel.betaReviewState, .succeeded(message: "Submitted to TestFlight review. State: In Review"))
    }

    func testRefreshLatestBuildTestFlightStatusShowsBetaReviewState() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        project.lastUpload = UploadSummary(version: "1.2.6", buildNumber: "1", uploadedAt: Date(), succeeded: true, message: "Upload finished successfully.")
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "WAITING_FOR_REVIEW")]
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

        XCTAssertEqual(appStoreConnect.fetchBuildRequests, [
            FakeAppStoreConnectClient.FetchBuildRequest(appID: "app-123", appVersion: "1.2.6", buildNumber: "1")
        ])
        XCTAssertEqual(viewModel.betaReviewState, .succeeded(message: "TestFlight status: Waiting for Review"))
    }

    func testRefreshLatestBuildTestFlightStatusReadsBetaReviewSubmissionWhenBuildOmitsState() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: nil)],
            betaReviewSubmissionsByBuildID: [
                "build-123": ASCBetaReviewSubmission(id: "submission-123", betaReviewState: "WAITING_FOR_REVIEW")
            ]
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

        XCTAssertEqual(appStoreConnect.fetchBetaReviewSubmissionBuildIDs, ["build-123"])
        XCTAssertEqual(viewModel.betaReviewState, .succeeded(message: "TestFlight status: Waiting for Review"))
        guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
            return XCTFail("Expected loaded distribution snapshot")
        }
        XCTAssertEqual(snapshot.betaReviewState, "WAITING_FOR_REVIEW")
        XCTAssertEqual(snapshot.betaReviewStateText, "Waiting for Review")
    }

    func testRefreshLatestBuildTestFlightStatusDoesNotRequireLastUploadSuccess() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "IN_REVIEW")]
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

        XCTAssertEqual(appStoreConnect.fetchBuildRequests, [
            FakeAppStoreConnectClient.FetchBuildRequest(appID: "app-123", appVersion: "1.2.6", buildNumber: "1")
        ])
        XCTAssertEqual(viewModel.betaReviewState, .succeeded(message: "TestFlight status: In Review"))
    }

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
            buildsByBetaGroupID: [
                "internal": [ASCBuild(id: "build-123", version: "1", processingState: "VALID")],
                "external-a": [ASCBuild(id: "build-123", version: "1", processingState: "VALID")]
            ]
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
        XCTAssertEqual(appStoreConnect.fetchBuildsForBetaGroupIDs, ["internal", "external-a", "external-b"])
        guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
            return XCTFail("Expected loaded distribution snapshot")
        }
        XCTAssertEqual(snapshot.betaReviewStateText, "Waiting for Review")
        XCTAssertEqual(snapshot.internalGroups.map(\.name), ["内部测试"])
        XCTAssertEqual(snapshot.externalGroups.map(\.name), ["外部测试 A", "外部测试 B"])
        XCTAssertEqual(snapshot.externalGroups.map(\.isCurrentBuildAssociated), [true, false])
        XCTAssertEqual(snapshot.externalGroups.first?.publicLink, "https://testflight.apple.com/join/a")
    }

    func testApprovedBuildAutoLinksSelectedExternalGroupsAndEnablesPublicLinks() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        project.autoLinkExternalGroupIDsAfterBetaApproval = ["external-a"]
        let allGroups = [
            ASCBetaGroup(id: "internal", name: "内部测试", isInternalGroup: true, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: nil),
            ASCBetaGroup(id: "external-a", name: "外部测试 A", isInternalGroup: false, publicLinkEnabled: false, publicLink: nil, publicLinkLimit: 100),
            ASCBetaGroup(id: "external-b", name: "外部测试 B", isInternalGroup: false, publicLinkEnabled: true, publicLink: "https://testflight.apple.com/join/b", publicLinkLimit: nil)
        ]
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [ASCBuild(id: "build-123", version: "1", processingState: "VALID", betaReviewState: "APPROVED")],
            betaGroups: allGroups,
            buildsByBetaGroupID: [
                "external-b": [ASCBuild(id: "build-123", version: "1", processingState: "VALID")]
            ]
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
            buildsByBetaGroupID: [:]
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

    func testManualLinkExternalGroupLinksSelectedExternalGroupOnly() async {
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
            buildsByBetaGroupID: [:]
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

        await viewModel.linkExternalGroupForLatestBuild(groupID: "external")

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
            buildsByBetaGroupID: [:]
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

        await viewModel.linkExternalGroupForLatestBuild(groupID: "external-b")

        XCTAssertEqual(appStoreConnect.addedBuildsToGroups.map(\.betaGroupID), ["external-b"])
        XCTAssertEqual(appStoreConnect.enabledPublicLinks.map(\.betaGroupID), ["external-b"])
        guard case let .loaded(snapshot) = viewModel.testFlightDistributionState else {
            return XCTFail("Expected loaded snapshot")
        }
        XCTAssertEqual(snapshot.externalGroups.first(where: { $0.id == "external-a" })?.operationState, .idle)
        if case let .failed(message) = snapshot.externalGroups.first(where: { $0.id == "external-b" })?.operationState {
            XCTAssertTrue(message.contains("unavailable"))
        } else {
            XCTFail("Expected failed operation state for external-b")
        }
        XCTAssertEqual(viewModel.betaReviewState, .failed(message: "Linked external groups with 1 failure."))
    }

    func testRefreshAppStoreReviewStatusDefaultsSelectedBuildFromLastSuccessfulUpload() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        var project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        project.lastUpload = UploadSummary(version: "1.2.6", buildNumber: "2", uploadedAt: Date(), succeeded: true, message: "Uploaded")
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [
                ASCBuild(id: "build-1", version: "1", processingState: "VALID"),
                ASCBuild(id: "build-2", version: "2", processingState: "VALID"),
                ASCBuild(id: "build-3", version: "3", processingState: "VALID")
            ],
            appStoreVersions: [
                ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")
            ],
            boundAppStoreVersionBuildIDs: ["version-123": "build-1"],
            appStoreReviewDetail: ASCAppStoreReviewDetail(
                id: "review-detail-123",
                contactFirstName: "Jerry",
                contactLastName: "Pop",
                contactPhone: "+82 10-0000-0000",
                contactEmail: "jerry@example.com",
                demoAccountName: "demo@example.com",
                demoAccountPassword: nil,
                demoAccountRequired: true,
                notes: "Use demo account."
            ),
            appStoreVersionLocalizations: [
                ASCAppStoreVersionLocalization(
                    id: "loc-zh",
                    locale: "zh-Hans",
                    description: "介绍",
                    keywords: "工具",
                    marketingURL: nil,
                    promotionalText: nil,
                    supportURL: "https://example.com/support",
                    whatsNew: "修复问题"
                )
            ],
            appScreenshotSetsByLocalizationID: [
                "loc-zh": [
                    ASCAppScreenshotSet(id: "set-iphone-65", screenshotDisplayType: "APP_IPHONE_65")
                ]
            ],
            appScreenshotsBySetID: [
                "set-iphone-65": [
                    ASCAppScreenshot(
                        id: "shot-1",
                        fileName: "screen1.png",
                        fileSize: 12345,
                        imageURLTemplate: "https://example.com/{w}x{h}.png",
                        width: 1242,
                        height: 2688,
                        assetDeliveryState: "COMPLETE"
                    )
                ]
            ]
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

        await viewModel.refreshAppStoreReviewStatus()

        XCTAssertEqual(appStoreConnect.fetchBuildRequests, [
            FakeAppStoreConnectClient.FetchBuildRequest(appID: "app-123", appVersion: "1.2.6", buildNumber: nil)
        ])
        guard case let .loaded(snapshot) = viewModel.appStoreReviewState else {
            return XCTFail("Expected loaded App Store review snapshot")
        }
        XCTAssertEqual(snapshot.versionString, "1.2.6")
        XCTAssertEqual(snapshot.selectedBuildID, "build-2")
        XCTAssertEqual(snapshot.boundBuildID, "build-1")
        XCTAssertEqual(snapshot.builds.map(\.buildNumber), ["1", "2", "3"])
        XCTAssertEqual(snapshot.reviewDetail?.contactEmail, "jerry@example.com")
        XCTAssertEqual(snapshot.localizations.map(\.locale), ["zh-Hans"])
        XCTAssertEqual(appStoreConnect.fetchedScreenshotSetLocalizationIDs, ["loc-zh"])
        XCTAssertEqual(appStoreConnect.fetchedScreenshotSetIDs, ["set-iphone-65"])
        XCTAssertEqual(snapshot.screenshotSets, [
            AppStoreReviewScreenshotSet(
                id: "set-iphone-65",
                localizationID: "loc-zh",
                locale: "zh-Hans",
                screenshotDisplayType: "APP_IPHONE_65",
                screenshots: [
                    ASCAppScreenshot(
                        id: "shot-1",
                        fileName: "screen1.png",
                        fileSize: 12345,
                        imageURLTemplate: "https://example.com/{w}x{h}.png",
                        width: 1242,
                        height: 2688,
                        assetDeliveryState: "COMPLETE"
                    )
                ]
            )
        ])
    }

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

    func testSaveAppStoreReviewAdvancedDraftUpdatesRemoteFieldsAndRefreshesSnapshot() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [
                ASCBuild(id: "build-1", version: "1", processingState: "VALID")
            ],
            appStoreVersions: [
                ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")
            ],
            appStoreReviewDetail: ASCAppStoreReviewDetail(
                id: "review-detail-123",
                contactFirstName: "old",
                contactLastName: "name",
                contactPhone: "100",
                contactEmail: "old@example.com",
                demoAccountName: "old-demo",
                demoAccountPassword: "old-pass",
                demoAccountRequired: true,
                notes: "old notes"
            ),
            appStoreVersionLocalizations: [
                ASCAppStoreVersionLocalization(
                    id: "loc-zh",
                    locale: "zh-Hans",
                    description: "旧描述",
                    keywords: "旧关键词",
                    marketingURL: nil,
                    promotionalText: nil,
                    supportURL: "https://old.example.com/support",
                    whatsNew: "旧更新"
                )
            ]
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
        await viewModel.refreshAppStoreReviewStatus()

        await viewModel.saveAppStoreReviewAdvancedDraft(
            AppStoreReviewAdvancedDraft(
                reviewDetailID: "review-detail-123",
                reviewDetailUpdate: ASCAppStoreReviewDetailUpdate(
                    contactFirstName: "ye",
                    contactLastName: "zhina",
                    contactPhone: "+861777",
                    contactEmail: "mdc@example.com",
                    demoAccountName: "13662388632",
                    demoAccountPassword: "123456",
                    demoAccountRequired: true,
                    notes: "新备注"
                ),
                localizationUpdates: [
                    AppStoreReviewLocalizationUpdate(
                        localizationID: "loc-zh",
                        update: ASCAppStoreVersionLocalizationUpdate(
                            description: "新描述",
                            keywords: "新关键词",
                            marketingURL: "https://example.com",
                            promotionalText: "新宣传",
                            supportURL: "https://example.com/support",
                            whatsNew: "新版本更新内容"
                        )
                    )
                ]
            )
        )

        XCTAssertEqual(appStoreConnect.updatedLocalizations.count, 1)
        XCTAssertEqual(appStoreConnect.updatedLocalizations.first?.localizationID, "loc-zh")
        XCTAssertEqual(appStoreConnect.updatedLocalizations.first?.update.whatsNew, "新版本更新内容")
        XCTAssertEqual(appStoreConnect.updatedReviewDetails.count, 1)
        XCTAssertEqual(appStoreConnect.updatedReviewDetails.first?.reviewDetailID, "review-detail-123")
        XCTAssertEqual(appStoreConnect.updatedReviewDetails.first?.update.demoAccountPassword, "123456")

        guard case let .loaded(snapshot) = viewModel.appStoreReviewState else {
            return XCTFail("Expected refreshed App Store review snapshot")
        }
        XCTAssertEqual(snapshot.localizations.first?.whatsNew, "新版本更新内容")
        XCTAssertEqual(snapshot.localizations.first?.description, "新描述")
        XCTAssertEqual(snapshot.reviewDetail?.contactEmail, "mdc@example.com")
        XCTAssertEqual(snapshot.reviewDetail?.demoAccountPassword, "123456")
    }

    func testBindSelectedAppStoreBuildUsesUserSelectedBuild() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [
                ASCBuild(id: "build-1", version: "1", processingState: "VALID"),
                ASCBuild(id: "build-2", version: "2", processingState: "VALID"),
                ASCBuild(id: "build-3", version: "3", processingState: "VALID")
            ],
            appStoreVersions: [
                ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")
            ],
            boundAppStoreVersionBuildIDs: ["version-123": "build-1"]
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

        await viewModel.refreshAppStoreReviewStatus()
        viewModel.selectAppStoreReviewBuild("build-3")
        await viewModel.bindSelectedAppStoreReviewBuild()

        XCTAssertEqual(appStoreConnect.updatedAppStoreVersionBuilds, [
            FakeAppStoreConnectClient.UpdatedAppStoreVersionBuild(appStoreVersionID: "version-123", buildID: "build-3")
        ])
        guard case let .loaded(snapshot) = viewModel.appStoreReviewState else {
            return XCTFail("Expected loaded App Store review snapshot")
        }
        XCTAssertEqual(snapshot.selectedBuildID, "build-3")
        XCTAssertEqual(snapshot.boundBuildID, "build-3")
    }

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

    func testSubmitAutoBindKeepsBuildIsBoundConsistentWhenLaterStepFails() async {
        let account = AppleAccountProfile(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!, displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123", lastVerifiedAt: nil)
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let appStoreConnect = FakeAppStoreConnectClient(
            app: ASCApp(id: "app-123", name: "Demo", bundleID: "com.example.demo"),
            builds: [ASCBuild(id: "build-1", version: "1", processingState: "VALID")],
            appStoreVersions: [ASCAppStoreVersion(id: "version-123", versionString: "1.2.6", state: "PREPARE_FOR_SUBMISSION", releaseType: "MANUAL")],
            // Not yet bound server-side, so submit takes the auto-bind branch.
            boundAppStoreVersionBuildIDs: [:]
        )
        appStoreConnect.submitReviewSubmissionError = TestError.unavailable
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(), accountStore: FakeAppleAccountProfileStore(), credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(), checkEngine: FakeConfigurationCheckEngine(), uploadRunner: FakeUploadJobRunner(),
            appStoreConnectClient: appStoreConnect, projects: [project], accountProfiles: [account]
        )
        await viewModel.refreshAppStoreReviewStatus()
        viewModel.selectAppStoreReviewBuild("build-1")

        await viewModel.submitSelectedAppStoreReview()

        // The auto-bind call itself succeeded before the later submit step threw.
        XCTAssertEqual(appStoreConnect.updatedAppStoreVersionBuilds, [FakeAppStoreConnectClient.UpdatedAppStoreVersionBuild(appStoreVersionID: "version-123", buildID: "build-1")])
        guard case let .failed(_, snapshot) = viewModel.appStoreReviewState, let snapshot else {
            return XCTFail("Expected failed App Store review snapshot")
        }
        XCTAssertEqual(snapshot.boundBuildID, "build-1")
        XCTAssertEqual(snapshot.builds.first(where: { $0.id == "build-1" })?.isBound, true, "build.isBound must agree with boundBuildID on the failure snapshot")
    }

    func testAutomaticChecksRunOnceWhenReady() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let results = [CheckResult(id: "bundle-id", title: "Bundle ID 已找到", message: "com.example.demo", severity: .green)]
        let checkEngine = FakeConfigurationCheckEngine(results: results)
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(savedKeys: [account.id: "stored-key"]),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: FakeUploadJobRunner(),
            projects: [project],
            accountProfiles: [account]
        )

        await viewModel.runChecksAutomaticallyIfNeeded()
        await viewModel.runChecksAutomaticallyIfNeeded()

        XCTAssertEqual(checkEngine.runCallCount, 1)
        XCTAssertEqual(viewModel.checkResults, results)
        XCTAssertTrue(viewModel.checksAreCurrent)
    }

    func testAutomaticChecksWaitForSavedPrivateKey() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let checkEngine = FakeConfigurationCheckEngine()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: FakeUploadJobRunner(),
            projects: [project],
            accountProfiles: [account]
        )

        await viewModel.runChecksAutomaticallyIfNeeded()

        XCTAssertEqual(checkEngine.runCallCount, 0)
        XCTAssertTrue(viewModel.checkResults.isEmpty)
    }

    func testDeleteProjectRemovesPersistsAndSelectsNextProject() {
        let first = makeProject(name: "First")
        let second = makeProject(name: "Second")
        let store = FakeProjectProfileStore()
        let viewModel = AppViewModel(
            store: store,
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [first, second]
        )

        viewModel.deleteProject(first.id)

        XCTAssertEqual(viewModel.projects, [second])
        XCTAssertEqual(viewModel.selectedProject?.id, second.id)
        XCTAssertEqual(store.savedProfiles, [second])
    }

    func testDeleteProjectsRemovesMultiplePersistsAndSelectsRemainingProject() {
        let first = makeProject(name: "First")
        let second = makeProject(name: "Second")
        let third = makeProject(name: "Third")
        let store = FakeProjectProfileStore()
        let viewModel = AppViewModel(
            store: store,
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [first, second, third]
        )

        viewModel.deleteProjects([first.id, third.id])

        XCTAssertEqual(viewModel.projects, [second])
        XCTAssertEqual(viewModel.selectedProject?.id, second.id)
        XCTAssertEqual(store.savedProfiles, [second])
    }

    func testUploadInProgressLocksProjectAndAccountChanges() async {
        let firstAccount = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "First",
            keyID: "FIRSTKEY01",
            issuerID: "first-issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let secondAccount = AppleAccountProfile(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            displayName: "Second",
            keyID: "SECONDKEY1",
            issuerID: "second-issuer",
            teamID: "TEAM456",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: firstAccount.id)
        let runner = SuspendingUploadJobRunner(events: [
            UploadEvent(step: .upload, message: "Upload complete", succeeded: true)
        ])
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: runner,
            projects: [project],
            accountProfiles: [firstAccount, secondAccount]
        )

        await viewModel.runChecks()
        let uploadTask = Task {
            await viewModel.startUpload()
        }
        await runner.waitUntilStarted()

        XCTAssertTrue(viewModel.isOperationRunning)
        XCTAssertTrue(viewModel.isUploadInProgress)

        viewModel.updateSelectedProjectVersion("9.9.9")
        viewModel.updateAccountDraft(displayName: "Changed", keyID: "CHANGEDKEY", issuerID: "changed-issuer", teamID: "CHANGED")
        viewModel.selectAccountProfile(secondAccount.id)

        XCTAssertEqual(viewModel.selectedProject?.version, "1.2.6")
        XCTAssertEqual(viewModel.accountProfile?.id, firstAccount.id)
        XCTAssertEqual(viewModel.accountDraft.displayName, "First")

        runner.finish()
        await uploadTask.value
    }

    func testScanProjectPathAddsScannedProjectAndSelectsIt() async throws {
        let scanned = ProjectScanResult(
            projectPath: URL(fileURLWithPath: "/tmp/Demo"),
            workspacePath: URL(fileURLWithPath: "/tmp/Demo/Demo.xcworkspace"),
            projectFilePath: nil,
            schemes: ["Demo"],
            selectedScheme: "Demo",
            bundleID: "com.example.demo",
            version: "1.0",
            buildNumber: "10",
            teamID: "TEAM123"
        )
        let scanner = FakeProjectScanner(result: scanned)
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: scanner,
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner()
        )

        try await viewModel.scanProject(atPath: "/tmp/Demo")

        XCTAssertEqual(viewModel.projects.count, 1)
        XCTAssertEqual(viewModel.selectedProject?.projectPath, "/tmp/Demo")
        XCTAssertEqual(viewModel.selectedProject?.bundleID, "com.example.demo")
    }

    func testAddProjectFromDirectoryScansAndAppendsWithoutReplacingSelectedProject() async throws {
        let existing = makeProject(name: "Existing")
        let scanned = ProjectScanResult(
            projectPath: URL(fileURLWithPath: "/tmp/NewDemo"),
            workspacePath: URL(fileURLWithPath: "/tmp/NewDemo/NewDemo.xcworkspace"),
            projectFilePath: nil,
            schemes: ["NewDemo"],
            selectedScheme: "NewDemo",
            bundleID: "com.example.newdemo",
            version: "2.0",
            buildNumber: "20",
            teamID: "NEWTEAM123"
        )
        let scanner = FakeProjectScanner(result: scanned)
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: scanner,
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [existing]
        )

        try await viewModel.addProjectFromDirectory(URL(fileURLWithPath: "/tmp/NewDemo"))

        XCTAssertEqual(scanner.scannedPaths, ["/tmp/NewDemo"])
        XCTAssertEqual(viewModel.projects.count, 2)
        XCTAssertEqual(viewModel.projects[0].id, existing.id)
        XCTAssertEqual(viewModel.projects[0].projectPath, existing.projectPath)
        XCTAssertEqual(viewModel.selectedProject?.projectPath, "/tmp/NewDemo")
        XCTAssertEqual(viewModel.selectedProject?.bundleID, "com.example.newdemo")
    }

    func testRunChecksWithoutValidAccountFailsWithClearState() async {
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [makeProject(name: "Demo")]
        )

        await viewModel.runChecks()

        XCTAssertEqual(viewModel.uploadState, .failed(message: "Select or enter an Apple account before running checks."))
        XCTAssertTrue(viewModel.checkResults.isEmpty)
    }

    func testRunChecksStoresReturnedResults() async {
        let project = makeProject(name: "Demo")
        let results = [CheckResult(id: "team", title: "Warn", message: "Confirm team", severity: .yellow)]
        let checkEngine = FakeConfigurationCheckEngine(results: results)
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: FakeUploadJobRunner(),
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.runChecks()

        XCTAssertEqual(viewModel.checkResults, results)
        XCTAssertEqual(checkEngine.lastProject?.id, project.id)
        XCTAssertEqual(checkEngine.lastAccount?.displayName, "Company")
        XCTAssertEqual(viewModel.uploadState, .idle)
    }

    func testStartUploadFailsWithoutSelectedProject() async {
        let runner = FakeUploadJobRunner()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: runner
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.startUpload()

        XCTAssertEqual(viewModel.uploadState, .failed(message: "Select a project before starting upload."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testStartUploadFailsWithoutAccount() async {
        let runner = FakeUploadJobRunner()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: runner,
            projects: [makeProject(name: "Demo")]
        )

        await viewModel.startUpload()

        XCTAssertEqual(viewModel.uploadState, .failed(message: "Select or enter an Apple account before uploading."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testStartUploadRunsChecksAndWritesCheckSummaryBeforeUpload() async {
        let uploadEvents = [UploadEvent(step: .upload, message: "Upload complete", succeeded: true)]
        let runner = FakeUploadJobRunner(events: uploadEvents)
        let checkEngine = FakeConfigurationCheckEngine(
            results: [
                CheckResult(id: "xcode", title: "Xcode 可用", message: "Xcode 26.6", severity: .green),
                CheckResult(id: "bundle", title: "Bundle ID 已找到", message: "com.example.demo", severity: .green)
            ]
        )
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.startUpload()

        XCTAssertEqual(checkEngine.runCallCount, 1)
        XCTAssertEqual(runner.receivedProjects.count, 1)
        XCTAssertEqual(viewModel.uploadEvents.map(\.step), [.checkBundleAndApp, .upload])
        XCTAssertEqual(viewModel.uploadEvents.first?.succeeded, true)
        XCTAssertTrue(viewModel.uploadEvents.first?.message.contains("[OK] Xcode 可用") == true)
        XCTAssertEqual(viewModel.uploadState, .succeeded(message: "Upload finished successfully."))
    }

    func testStartUploadUsesSelectedLanguageForChecksAndConsoleMessages() async {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let project = makeProject(name: "Demo", version: "1.2.6", buildNumber: "1", selectedAccountID: account.id)
        let checkEngine = FakeConfigurationCheckEngine()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: FakeUploadJobRunner(),
            projects: [project],
            accountProfiles: [account],
            language: .simplifiedChinese
        )

        await viewModel.startUpload()

        XCTAssertEqual(checkEngine.lastLanguage, .simplifiedChinese)
        XCTAssertEqual(viewModel.uploadEvents.first?.message, "[OK] 配置检查完成，没有发现问题。")
        XCTAssertEqual(viewModel.uploadState, .succeeded(message: "上传成功完成。"))
    }

    func testProjectEditsInvalidateChecksAndBlockUploadUntilChecksRerun() async {
        let runner = FakeUploadJobRunner()
        let checkEngine = FakeConfigurationCheckEngine()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.runChecks()
        viewModel.updateSelectedProjectVersion("2.0")

        await viewModel.startUpload()

        XCTAssertEqual(checkEngine.runCallCount, 1)
        XCTAssertTrue(viewModel.checkResults.isEmpty)
        XCTAssertEqual(
            viewModel.uploadState,
            .failed(message: "Apply project changes before uploading.")
        )
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testEditingBuildNumberBlocksChecksUntilProjectChangesAreApplied() async {
        let project = makeProject(name: "Demo", version: "1.0", buildNumber: "1")
        let checkEngine = FakeConfigurationCheckEngine()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: FakeUploadJobRunner(),
            projectMutator: FakeProjectMutator(),
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        viewModel.updateSelectedProjectBuildNumber("2")
        await viewModel.runChecks()

        XCTAssertTrue(viewModel.hasUnappliedProjectChanges)
        XCTAssertEqual(viewModel.projectMutationSummary, ["Build Number: 1 -> 2"])
        XCTAssertEqual(checkEngine.runCallCount, 0)
        XCTAssertEqual(viewModel.uploadState, .failed(message: "Apply project changes before running checks."))
    }

    func testClearingBundleIDAllowsChecksToSurfaceMissingFieldErrors() async {
        let project = makeProject(name: "Demo", version: "1.0", buildNumber: "1")
        let results = [
            CheckResult(id: "bundle-id", title: "Missing Bundle ID", message: "Bundle ID is required.", severity: .red)
        ]
        let checkEngine = FakeConfigurationCheckEngine(results: results)
        let runner = FakeUploadJobRunner()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)
        viewModel.updateSelectedProjectBundleID("")

        XCTAssertFalse(viewModel.hasUnappliedProjectChanges)
        XCTAssertTrue(viewModel.projectMutationSummary.isEmpty)

        await viewModel.startUpload()

        XCTAssertEqual(checkEngine.runCallCount, 1)
        XCTAssertEqual(checkEngine.lastProject?.bundleID, nil)
        XCTAssertEqual(viewModel.checkResults, results)
        XCTAssertEqual(viewModel.uploadState, .failed(message: "Upload blocked by configuration issues. Resolve red checks before uploading."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testClearingBuildNumberAllowsChecksToSurfaceMissingFieldErrors() async {
        let project = makeProject(name: "Demo", version: "1.0", buildNumber: "1")
        let results = [
            CheckResult(id: "build-number", title: "Missing Build Number", message: "Build number is required.", severity: .red)
        ]
        let checkEngine = FakeConfigurationCheckEngine(results: results)
        let runner = FakeUploadJobRunner()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)
        viewModel.updateSelectedProjectBuildNumber("   ")

        XCTAssertFalse(viewModel.hasUnappliedProjectChanges)
        XCTAssertTrue(viewModel.projectMutationSummary.isEmpty)

        await viewModel.startUpload()

        XCTAssertEqual(checkEngine.runCallCount, 1)
        XCTAssertEqual(checkEngine.lastProject?.buildNumber, nil)
        XCTAssertEqual(viewModel.checkResults, results)
        XCTAssertEqual(viewModel.uploadState, .failed(message: "Upload blocked by configuration issues. Resolve red checks before uploading."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testApplyProjectChangesClearsUnappliedState() async throws {
        let project = makeProject(name: "Demo", version: "1.0", buildNumber: "1")
        let mutator = FakeProjectMutator()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projectMutator: mutator,
            projects: [project]
        )

        viewModel.updateSelectedProjectBuildNumber("2")
        try viewModel.applyProjectChanges()

        XCTAssertEqual(mutator.appliedPlans.count, 1)
        XCTAssertFalse(viewModel.hasUnappliedProjectChanges)
        XCTAssertTrue(viewModel.projectMutationSummary.isEmpty)
        XCTAssertEqual(viewModel.selectedProject?.buildNumber, "2")
    }

    func testUploadCannotProceedWithUnappliedProjectChanges() async {
        let project = makeProject(name: "Demo", version: "1.0", buildNumber: "1")
        let runner = FakeUploadJobRunner()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: runner,
            projectMutator: FakeProjectMutator(),
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.runChecks()
        viewModel.updateSelectedProjectBuildNumber("2")
        await viewModel.startUpload()

        XCTAssertEqual(viewModel.uploadState, .failed(message: "Apply project changes before uploading."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testSavedProjectEditsStayUnappliedAfterReloadUntilApplyOrScan() async throws {
        let store = FakeProjectProfileStore()
        let runner = FakeUploadJobRunner()
        let originalProject = makeProject(name: "Demo", version: "1.0", buildNumber: "1")
        let firstViewModel = AppViewModel(
            store: store,
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: runner,
            projectMutator: FakeProjectMutator(),
            projects: [originalProject]
        )

        firstViewModel.updateSelectedProjectBuildNumber("2")
        try firstViewModel.saveProjects()

        let reloadedRunner = FakeUploadJobRunner()
        let reloadedChecks = FakeConfigurationCheckEngine()
        let reloadedViewModel = AppViewModel(
            store: store,
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: reloadedChecks,
            uploadRunner: reloadedRunner,
            projectMutator: FakeProjectMutator()
        )

        try reloadedViewModel.loadProjects()
        reloadedViewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        XCTAssertEqual(reloadedViewModel.selectedProject?.buildNumber, "2")
        XCTAssertTrue(reloadedViewModel.hasUnappliedProjectChanges)
        XCTAssertEqual(reloadedViewModel.projectMutationSummary, ["Build Number: 1 -> 2"])

        await reloadedViewModel.runChecks()
        XCTAssertEqual(reloadedChecks.runCallCount, 0)
        XCTAssertEqual(reloadedViewModel.uploadState, .failed(message: "Apply project changes before running checks."))

        await reloadedViewModel.startUpload()
        XCTAssertEqual(reloadedViewModel.uploadState, .failed(message: "Apply project changes before uploading."))
        XCTAssertTrue(reloadedRunner.receivedProjects.isEmpty)
    }

    func testAccountEditsInvalidateChecksAndUploadRunsFreshChecks() async {
        let runner = FakeUploadJobRunner()
        let checkEngine = FakeConfigurationCheckEngine()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.runChecks()
        viewModel.updateAccountDraft(displayName: "Updated Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.startUpload()

        XCTAssertEqual(checkEngine.runCallCount, 2)
        XCTAssertTrue(viewModel.checkResults.isEmpty)
        XCTAssertEqual(viewModel.uploadState, .succeeded(message: "Upload finished successfully."))
        XCTAssertEqual(runner.receivedAccounts.first?.displayName, "Updated Company")
    }

    func testStartUploadFailsWhenRedChecksBlockUpload() async {
        let runner = FakeUploadJobRunner()
        let checkEngine = FakeConfigurationCheckEngine(
            results: [CheckResult(id: "bundle", title: "Missing Bundle", message: "No bundle", severity: .red)]
        )
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.runChecks()
        await viewModel.startUpload()

        XCTAssertEqual(viewModel.uploadState, .failed(message: "Upload blocked by configuration issues. Resolve red checks before uploading."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testStartUploadContinuesWhenYellowChecksWarn() async {
        let runner = FakeUploadJobRunner()
        let checkEngine = FakeConfigurationCheckEngine(
            results: [CheckResult(id: "team", title: "Confirm Team", message: "Needs confirmation", severity: .yellow)]
        )
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.startUpload()

        XCTAssertEqual(viewModel.uploadState, .succeeded(message: "Upload finished successfully."))
        XCTAssertEqual(runner.receivedProjects.count, 1)
        XCTAssertEqual(viewModel.uploadEvents.first?.step, .checkBundleAndApp)
        XCTAssertEqual(viewModel.uploadEvents.first?.message, "[WARN] Confirm Team\nNeeds confirmation")
    }

    func testStartUploadWithConfirmedYellowIssuesRunsUploadAndCapturesEvents() async {
        let project = makeProject(name: "Demo", version: "1.2.3", buildNumber: "42")
        let events = [
            UploadEvent(step: .archive, message: "Archive complete", succeeded: true),
            UploadEvent(step: .upload, message: "Upload complete", succeeded: true)
        ]
        let runner = FakeUploadJobRunner(events: events)
        let checkEngine = FakeConfigurationCheckEngine(
            results: [CheckResult(id: "team", title: "Confirm Team", message: "Needs confirmation", severity: .yellow)]
        )
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: checkEngine,
            uploadRunner: runner,
            projects: [project]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123")

        await viewModel.startUpload()

        XCTAssertEqual(runner.receivedProjects.first?.id, project.id)
        XCTAssertEqual(viewModel.uploadEvents.count, 3)
        XCTAssertEqual(viewModel.uploadEvents.first?.step, .checkBundleAndApp)
        XCTAssertEqual(viewModel.uploadEvents.first?.message, "[WARN] Confirm Team\nNeeds confirmation")
        XCTAssertEqual(Array(viewModel.uploadEvents.dropFirst()), events)
        XCTAssertEqual(viewModel.uploadState, .succeeded(message: "Upload finished successfully."))
        XCTAssertEqual(viewModel.selectedProject?.lastUpload?.version, "1.2.3")
        XCTAssertEqual(viewModel.selectedProject?.lastUpload?.buildNumber, "42")
        XCTAssertEqual(viewModel.selectedProject?.lastUpload?.succeeded, true)
    }

    func testSavedSelectedAccountReferenceSurvivesLoadSelectAndEdit() throws {
        let account = AppleAccountProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            displayName: "Company",
            keyID: "KEY1234567",
            issuerID: "issuer",
            teamID: "TEAM123",
            lastVerifiedAt: nil
        )
        let firstProject = makeProject(name: "First", selectedAccountID: account.id)
        let secondProject = makeProject(name: "Second")
        let projectStore = FakeProjectProfileStore(loadResult: [firstProject, secondProject])
        let accountStore = FakeAppleAccountProfileStore(loadResult: [account])
        let viewModel = AppViewModel(
            store: projectStore,
            accountStore: accountStore,
            credentialVault: FakeCredentialVault(savedKeys: [account.id: "stored-key"]),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner()
        )

        try viewModel.loadProjects()
        viewModel.selectProject(secondProject.id)
        viewModel.selectProject(firstProject.id)
        viewModel.updateSelectedProjectName("Renamed First")
        try viewModel.saveProjects()

        XCTAssertEqual(viewModel.selectedProject?.selectedAccountID, account.id)
        XCTAssertEqual(viewModel.accountProfile?.id, account.id)
        XCTAssertEqual(viewModel.accountDraft.displayName, "Company")
        XCTAssertEqual(projectStore.savedProfiles.first?.selectedAccountID, account.id)
        XCTAssertEqual(accountStore.savedProfiles, [account])
    }

    func testImportPrivateKeyPEMSavesToVaultWithoutExposingContent() throws {
        let vault = FakeCredentialVault()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: vault,
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123")

        try viewModel.importPrivateKeyPEM("-----BEGIN PRIVATE KEY-----\nABC123\n-----END PRIVATE KEY-----")

        let accountID = try XCTUnwrap(viewModel.accountProfile?.id)
        XCTAssertEqual(vault.savedKeys[accountID], "-----BEGIN PRIVATE KEY-----\nABC123\n-----END PRIVATE KEY-----")
        XCTAssertEqual(viewModel.privateKeyStatus, .saved)
        XCTAssertEqual(viewModel.accountDraft.keyID, "KEY1234567")
        XCTAssertEqual(viewModel.accountProfiles, [])
    }

    func testImportPrivateKeyFromUnreadableFileReportsVisibleFailure() throws {
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: FakeCredentialVault(),
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: "TEAM123")

        XCTAssertThrowsError(try viewModel.importPrivateKey(from: URL(fileURLWithPath: "/tmp/missing-key.p8")))
        XCTAssertEqual(viewModel.privateKeyStatus, .failed)
        XCTAssertEqual(viewModel.uploadState, .failed(message: "Failed to read the App Store Connect private key file."))
    }

    func testImportAppleAccountMetadataTextUpdatesDraftWithoutSavingPrivateKey() throws {
        let vault = FakeCredentialVault()
        let viewModel = AppViewModel(
            store: FakeProjectProfileStore(),
            accountStore: FakeAppleAccountProfileStore(),
            credentialVault: vault,
            scanner: FakeProjectScanner(),
            checkEngine: FakeConfigurationCheckEngine(),
            uploadRunner: FakeUploadJobRunner(),
            projects: [makeProject(name: "Demo")]
        )
        viewModel.updateAccountDraft(displayName: "Company", keyID: "OLDKEY", issuerID: "old-issuer", teamID: nil)

        try viewModel.importAppleAccountMetadataText("""
        Issuer ID: imported-issuer
        Key ID: NEWKEY1234
        Team ID: TEAM999999
        """)

        XCTAssertEqual(viewModel.accountDraft.displayName, "Company")
        XCTAssertEqual(viewModel.accountDraft.keyID, "NEWKEY1234")
        XCTAssertEqual(viewModel.accountDraft.issuerID, "imported-issuer")
        XCTAssertEqual(viewModel.accountDraft.teamID, "TEAM999999")
        XCTAssertTrue(vault.savedKeys.isEmpty)
        XCTAssertEqual(viewModel.privateKeyStatus, .missing)
    }
}

private func makeProject(
    name: String,
    version: String? = nil,
    buildNumber: String? = nil,
    selectedAccountID: UUID? = nil
) -> ProjectProfile {
    ProjectProfile(
        name: name,
        projectPath: "/tmp/\(name)",
        workspacePath: nil,
        projectFilePath: nil,
        scheme: "Demo",
        configuration: "Release",
        bundleID: "com.example.\(name.lowercased())",
        version: version,
        buildNumber: buildNumber,
        teamID: "TEAM123",
        selectedAccountID: selectedAccountID,
        lastUpload: nil
    )
}

private final class FakeAppStoreConnectClient: AppStoreConnectClientProtocol {
    struct FetchBuildRequest: Equatable {
        var appID: String
        var appVersion: String?
        var buildNumber: String?
    }

    struct UpdatedAppStoreVersionBuild: Equatable {
        var appStoreVersionID: String
        var buildID: String
    }

    var app: ASCApp?
    var bundle: ASCBundleID?
    var builds: [ASCBuild]
    var betaGroups: [ASCBetaGroup]
    var buildsByBetaGroupID: [String: [ASCBuild]]
    var betaReviewSubmissionsByBuildID: [String: ASCBetaReviewSubmission]
    var submission: ASCBetaReviewSubmission
    var appStoreVersions: [ASCAppStoreVersion]
    var boundAppStoreVersionBuildIDs: [String: String]
    var appStoreReviewDetail: ASCAppStoreReviewDetail?
    var appStoreVersionLocalizations: [ASCAppStoreVersionLocalization]
    var appScreenshotSetsByLocalizationID: [String: [ASCAppScreenshotSet]]
    var appScreenshotsBySetID: [String: [ASCAppScreenshot]]
    var reviewSubmission: ASCReviewSubmission
    var reviewSubmissionItem: ASCReviewSubmissionItem
    var activeReviewSubmission: ASCReviewSubmission?
    var addBuildFailuresByGroupID: [String: Error] = [:]
    var enablePublicLinkFailuresByGroupID: [String: Error] = [:]
    var submitReviewSubmissionError: Error?
    private(set) var fetchAppBundleIDs: [String] = []
    private(set) var fetchBuildRequests: [FetchBuildRequest] = []
    private(set) var fetchBuildsForBetaGroupIDs: [String] = []
    private(set) var fetchBetaReviewSubmissionBuildIDs: [String] = []
    private(set) var addedBuildsToGroups: [(buildID: String, betaGroupID: String)] = []
    private(set) var enabledPublicLinks: [(betaGroupID: String, limit: Int?)] = []
    private(set) var submittedBuildIDs: [String] = []
    private(set) var fetchedAppStoreVersionsForAppIDs: [String] = []
    private(set) var createdAppStoreVersions: [(appID: String, versionString: String, releaseType: String?)] = []
    private(set) var fetchedBoundBuildVersionIDs: [String] = []
    private(set) var updatedAppStoreVersionBuilds: [UpdatedAppStoreVersionBuild] = []
    private(set) var fetchedReviewDetailVersionIDs: [String] = []
    private(set) var fetchedLocalizationVersionIDs: [String] = []
    private(set) var updatedLocalizations: [(localizationID: String, update: ASCAppStoreVersionLocalizationUpdate)] = []
    private(set) var updatedReviewDetails: [(reviewDetailID: String, update: ASCAppStoreReviewDetailUpdate)] = []
    private(set) var fetchedScreenshotSetLocalizationIDs: [String] = []
    private(set) var fetchedScreenshotSetIDs: [String] = []
    private(set) var createdReviewSubmissionAppIDs: [String] = []
    private(set) var createdReviewSubmissionItems: [(reviewSubmissionID: String, appStoreVersionID: String)] = []
    private(set) var submittedReviewSubmissionIDs: [String] = []
    private(set) var fetchedActiveReviewSubmissionAppIDs: [String] = []
    private(set) var canceledReviewSubmissionIDs: [String] = []
    private(set) var updatedReleaseTypes: [(appStoreVersionID: String, releaseType: String)] = []
    private(set) var releasedAppStoreVersionIDs: [String] = []

    init(
        app: ASCApp? = nil,
        bundle: ASCBundleID? = nil,
        builds: [ASCBuild] = [],
        betaGroups: [ASCBetaGroup] = [],
        buildsByBetaGroupID: [String: [ASCBuild]] = [:],
        betaReviewSubmissionsByBuildID: [String: ASCBetaReviewSubmission] = [:],
        submission: ASCBetaReviewSubmission = ASCBetaReviewSubmission(id: "submission", betaReviewState: nil),
        appStoreVersions: [ASCAppStoreVersion] = [],
        boundAppStoreVersionBuildIDs: [String: String] = [:],
        appStoreReviewDetail: ASCAppStoreReviewDetail? = nil,
        appStoreVersionLocalizations: [ASCAppStoreVersionLocalization] = [],
        appScreenshotSetsByLocalizationID: [String: [ASCAppScreenshotSet]] = [:],
        appScreenshotsBySetID: [String: [ASCAppScreenshot]] = [:],
        reviewSubmission: ASCReviewSubmission = ASCReviewSubmission(id: "review-submission", state: "READY_FOR_REVIEW"),
        reviewSubmissionItem: ASCReviewSubmissionItem = ASCReviewSubmissionItem(id: "review-item", state: "READY_FOR_REVIEW"),
        activeReviewSubmission: ASCReviewSubmission? = nil
    ) {
        self.app = app
        self.bundle = bundle
        self.builds = builds
        self.betaGroups = betaGroups
        self.buildsByBetaGroupID = buildsByBetaGroupID
        self.betaReviewSubmissionsByBuildID = betaReviewSubmissionsByBuildID
        self.submission = submission
        self.appStoreVersions = appStoreVersions
        self.boundAppStoreVersionBuildIDs = boundAppStoreVersionBuildIDs
        self.appStoreReviewDetail = appStoreReviewDetail
        self.appStoreVersionLocalizations = appStoreVersionLocalizations
        self.appScreenshotSetsByLocalizationID = appScreenshotSetsByLocalizationID
        self.appScreenshotsBySetID = appScreenshotsBySetID
        self.reviewSubmission = reviewSubmission
        self.reviewSubmissionItem = reviewSubmissionItem
        self.activeReviewSubmission = activeReviewSubmission
    }

    func fetchApp(bundleID: String) async throws -> ASCApp? {
        fetchAppBundleIDs.append(bundleID)
        return app
    }

    func fetchBundleID(identifier: String) async throws -> ASCBundleID? {
        bundle
    }

    func fetchBuilds(appID: String, appVersion: String?, buildNumber: String?) async throws -> [ASCBuild] {
        fetchBuildRequests.append(FetchBuildRequest(appID: appID, appVersion: appVersion, buildNumber: buildNumber))
        return builds
    }

    func fetchBetaGroups(appID: String) async throws -> [ASCBetaGroup] {
        betaGroups
    }

    func fetchBuildsForBetaGroup(betaGroupID: String) async throws -> [ASCBuild] {
        fetchBuildsForBetaGroupIDs.append(betaGroupID)
        return buildsByBetaGroupID[betaGroupID] ?? []
    }

    func fetchBetaReviewSubmission(buildID: String) async throws -> ASCBetaReviewSubmission? {
        fetchBetaReviewSubmissionBuildIDs.append(buildID)
        return betaReviewSubmissionsByBuildID[buildID]
    }

    func addBuild(_ buildID: String, toBetaGroup betaGroupID: String) async throws {
        addedBuildsToGroups.append((buildID, betaGroupID))
        if let error = addBuildFailuresByGroupID[betaGroupID] {
            throw error
        }
    }

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

    func submitBetaReview(buildID: String) async throws -> ASCBetaReviewSubmission {
        submittedBuildIDs.append(buildID)
        return submission
    }

    func fetchAppStoreVersions(appID: String) async throws -> [ASCAppStoreVersion] {
        fetchedAppStoreVersionsForAppIDs.append(appID)
        return appStoreVersions
    }

    func createAppStoreVersion(appID: String, versionString: String, releaseType: String?) async throws -> ASCAppStoreVersion {
        createdAppStoreVersions.append((appID, versionString, releaseType))
        let version = ASCAppStoreVersion(id: "created-\(versionString)", versionString: versionString, state: "PREPARE_FOR_SUBMISSION", releaseType: releaseType)
        appStoreVersions.append(version)
        return version
    }

    func fetchAppStoreVersionBuildID(appStoreVersionID: String) async throws -> String? {
        fetchedBoundBuildVersionIDs.append(appStoreVersionID)
        return boundAppStoreVersionBuildIDs[appStoreVersionID]
    }

    func updateAppStoreVersionBuild(appStoreVersionID: String, buildID: String) async throws {
        updatedAppStoreVersionBuilds.append(UpdatedAppStoreVersionBuild(appStoreVersionID: appStoreVersionID, buildID: buildID))
        boundAppStoreVersionBuildIDs[appStoreVersionID] = buildID
    }

    func fetchAppStoreReviewDetail(appStoreVersionID: String) async throws -> ASCAppStoreReviewDetail? {
        fetchedReviewDetailVersionIDs.append(appStoreVersionID)
        return appStoreReviewDetail
    }

    func fetchAppStoreVersionLocalizations(appStoreVersionID: String) async throws -> [ASCAppStoreVersionLocalization] {
        fetchedLocalizationVersionIDs.append(appStoreVersionID)
        return appStoreVersionLocalizations
    }

    func updateAppStoreVersionLocalization(
        localizationID: String,
        update: ASCAppStoreVersionLocalizationUpdate
    ) async throws -> ASCAppStoreVersionLocalization {
        updatedLocalizations.append((localizationID, update))
        let locale = appStoreVersionLocalizations.first(where: { $0.id == localizationID })?.locale ?? "en-US"
        let updated = ASCAppStoreVersionLocalization(
            id: localizationID,
            locale: locale,
            description: update.description,
            keywords: update.keywords,
            marketingURL: update.marketingURL,
            promotionalText: update.promotionalText,
            supportURL: update.supportURL,
            whatsNew: update.whatsNew
        )
        appStoreVersionLocalizations.removeAll { $0.id == localizationID }
        appStoreVersionLocalizations.append(updated)
        return updated
    }

    func updateAppStoreReviewDetail(
        reviewDetailID: String,
        update: ASCAppStoreReviewDetailUpdate
    ) async throws -> ASCAppStoreReviewDetail {
        updatedReviewDetails.append((reviewDetailID, update))
        let updated = ASCAppStoreReviewDetail(
            id: reviewDetailID,
            contactFirstName: update.contactFirstName,
            contactLastName: update.contactLastName,
            contactPhone: update.contactPhone,
            contactEmail: update.contactEmail,
            demoAccountName: update.demoAccountName,
            demoAccountPassword: update.demoAccountPassword,
            demoAccountRequired: update.demoAccountRequired,
            notes: update.notes
        )
        appStoreReviewDetail = updated
        return updated
    }

    func fetchAppScreenshotSets(appStoreVersionLocalizationID: String) async throws -> [ASCAppScreenshotSet] {
        fetchedScreenshotSetLocalizationIDs.append(appStoreVersionLocalizationID)
        return appScreenshotSetsByLocalizationID[appStoreVersionLocalizationID] ?? []
    }

    func fetchAppScreenshots(appScreenshotSetID: String) async throws -> [ASCAppScreenshot] {
        fetchedScreenshotSetIDs.append(appScreenshotSetID)
        return appScreenshotsBySetID[appScreenshotSetID] ?? []
    }

    func createReviewSubmission(appID: String) async throws -> ASCReviewSubmission {
        createdReviewSubmissionAppIDs.append(appID)
        activeReviewSubmission = reviewSubmission
        return reviewSubmission
    }

    func createReviewSubmissionItem(reviewSubmissionID: String, appStoreVersionID: String) async throws -> ASCReviewSubmissionItem {
        createdReviewSubmissionItems.append((reviewSubmissionID, appStoreVersionID))
        return reviewSubmissionItem
    }

    func submitReviewSubmission(reviewSubmissionID: String) async throws -> ASCReviewSubmission {
        submittedReviewSubmissionIDs.append(reviewSubmissionID)
        if let error = submitReviewSubmissionError {
            throw error
        }
        let submitted = ASCReviewSubmission(id: reviewSubmissionID, state: "WAITING_FOR_REVIEW")
        activeReviewSubmission = submitted
        return submitted
    }

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
}

private final class FakeProjectProfileStore: ProjectProfileStoreProtocol {
    var loadResult: [ProjectProfile]
    var savedProfiles: [ProjectProfile] = []

    init(loadResult: [ProjectProfile] = []) {
        self.loadResult = loadResult
    }

    func load() throws -> [ProjectProfile] {
        loadResult
    }

    func save(_ profiles: [ProjectProfile]) throws {
        savedProfiles = profiles
        loadResult = profiles
    }
}

private final class FakeProjectScanner: ProjectScanning {
    var result: ProjectScanResult
    private(set) var scannedPaths: [String] = []

    init(result: ProjectScanResult = ProjectScanResult(
        projectPath: URL(fileURLWithPath: "/tmp/Default"),
        workspacePath: nil,
        projectFilePath: nil,
        schemes: ["Default"],
        selectedScheme: "Default",
        bundleID: "com.example.default",
        version: "1.0",
        buildNumber: "1",
        teamID: "TEAM123"
    )) {
        self.result = result
    }

    func scan(projectPath: URL) async throws -> ProjectScanResult {
        scannedPaths.append(projectPath.path)
        return result
    }
}

private final class FakeConfigurationCheckEngine: ConfigurationCheckEngineProtocol {
    var results: [CheckResult]
    private(set) var lastProject: ProjectProfile?
    private(set) var lastAccount: AppleAccountProfile?
    private(set) var lastLanguage: AppLanguage?
    private(set) var runCallCount = 0

    init(results: [CheckResult] = []) {
        self.results = results
    }

    func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult] {
        await run(project: project, account: account, language: .english)
    }

    func run(project: ProjectProfile, account: AppleAccountProfile, language: AppLanguage) async -> [CheckResult] {
        runCallCount += 1
        lastProject = project
        lastAccount = account
        lastLanguage = language
        return results
    }
}

private final class FakeAppUpdateChecker: AppUpdateChecking {
    var result: AppUpdateCheckResult
    var error: Error?
    private(set) var checkCallCount = 0

    init(result: AppUpdateCheckResult = .upToDate(currentVersion: "1.1.0", latestVersion: "1.1.0"), error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func checkForUpdate() async throws -> AppUpdateCheckResult {
        checkCallCount += 1
        if let error {
            throw error
        }
        return result
    }
}

private final class FakeUploadJobRunner: UploadJobRunning {
    var events: [UploadEvent]
    var error: Error?
    private(set) var receivedProjects: [ProjectProfile] = []
    private(set) var receivedAccounts: [AppleAccountProfile] = []

    init(events: [UploadEvent] = [], error: Error? = nil) {
        self.events = events
        self.error = error
    }

    func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile) async throws -> [UploadEvent] {
        receivedProjects.append(project)
        receivedAccounts.append(account)
        if let error {
            throw error
        }
        return events
    }
}

private final class SuspendingUploadJobRunner: UploadJobRunning {
    var events: [UploadEvent]
    private var started = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var finishContinuation: CheckedContinuation<Void, Never>?

    init(events: [UploadEvent]) {
        self.events = events
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func finish() {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile) async throws -> [UploadEvent] {
        started = true
        startContinuation?.resume()
        startContinuation = nil
        await withCheckedContinuation { continuation in
            finishContinuation = continuation
        }
        return events
    }
}

private final class FakeProjectMutator: ProjectMutating {
    private(set) var appliedPlans: [ProjectMutationPlan] = []

    func plan(
        project: ProjectProfile,
        targetBundleID: String?,
        targetVersion: String?,
        targetBuildNumber: String?,
        infoPlistURL: URL?
    ) throws -> ProjectMutationPlan {
        ProjectMutationPlan(
            request: ProjectMutationRequest(
                projectRoot: URL(fileURLWithPath: project.projectPath),
                pbxprojURL: URL(fileURLWithPath: project.projectPath).appendingPathComponent("\(project.name).xcodeproj/project.pbxproj"),
                infoPlistURL: infoPlistURL,
                targetName: project.scheme,
                currentBundleID: project.bundleID,
                newBundleID: targetBundleID,
                currentVersion: project.version,
                newVersion: targetVersion,
                currentBuildNumber: project.buildNumber,
                newBuildNumber: targetBuildNumber
            ),
            backupDirectory: URL(fileURLWithPath: project.projectPath).appendingPathComponent(".projpost-backups/test"),
            filesToBackup: [],
            changes: [
                ProjectMutationChange(summary: "Build Number: \(project.buildNumber ?? "-") -> \(targetBuildNumber ?? "-")", oldValue: project.buildNumber, newValue: targetBuildNumber)
            ].filter { $0.oldValue != $0.newValue }
        )
    }

    func apply(_ plan: ProjectMutationPlan) throws {
        appliedPlans.append(plan)
    }
}

private final class FakeAppleAccountProfileStore: AppleAccountProfileStoreProtocol {
    var loadResult: [AppleAccountProfile]
    var savedProfiles: [AppleAccountProfile] = []

    init(loadResult: [AppleAccountProfile] = []) {
        self.loadResult = loadResult
    }

    func load() throws -> [AppleAccountProfile] {
        loadResult
    }

    func save(_ profiles: [AppleAccountProfile]) throws {
        savedProfiles = profiles
        loadResult = profiles
    }
}

private final class FakeCredentialVault: CredentialVault {
    var savedKeys: [UUID: String]

    init(savedKeys: [UUID: String] = [:]) {
        self.savedKeys = savedKeys
    }

    func savePrivateKey(_ privateKeyPEM: String, for accountID: UUID) throws {
        savedKeys[accountID] = privateKeyPEM
    }

    func privateKey(for accountID: UUID) throws -> String {
        guard let key = savedKeys[accountID] else {
            throw CredentialVaultError.itemNotFound
        }
        return key
    }

    func deletePrivateKey(for accountID: UUID) throws {
        savedKeys.removeValue(forKey: accountID)
    }
}

private enum TestError: Error {
    case unavailable
}
