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

    func testStartUploadRequiresCurrentChecksBeforeUpload() async {
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
        viewModel.updateAccountDraft(displayName: "Company", keyID: "KEY1234567", issuerID: "issuer", teamID: nil)

        await viewModel.startUpload()

        XCTAssertEqual(
            viewModel.uploadState,
            .failed(message: "Run configuration checks for the current project and Apple account before uploading.")
        )
        XCTAssertTrue(runner.receivedProjects.isEmpty)
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
            .failed(message: "Run configuration checks for the current project and Apple account before uploading.")
        )
        XCTAssertTrue(runner.receivedProjects.isEmpty)
    }

    func testAccountEditsInvalidateChecksAndBlockUploadUntilChecksRerun() async {
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

        XCTAssertEqual(checkEngine.runCallCount, 1)
        XCTAssertTrue(viewModel.checkResults.isEmpty)
        XCTAssertEqual(
            viewModel.uploadState,
            .failed(message: "Run configuration checks for the current project and Apple account before uploading.")
        )
        XCTAssertTrue(runner.receivedProjects.isEmpty)
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

    func testStartUploadFailsWhenYellowChecksNeedConfirmation() async {
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

        await viewModel.runChecks()
        await viewModel.startUpload()

        XCTAssertEqual(viewModel.uploadState, .failed(message: "Upload requires confirmation for yellow configuration issues."))
        XCTAssertTrue(runner.receivedProjects.isEmpty)
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

        await viewModel.runChecks()

        await viewModel.startUpload(confirmedYellowIssues: true)

        XCTAssertEqual(runner.receivedProjects.first?.id, project.id)
        XCTAssertEqual(viewModel.uploadEvents, events)
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
    }
}

private final class FakeProjectScanner: ProjectScanning {
    var result: ProjectScanResult

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
        result
    }
}

private final class FakeConfigurationCheckEngine: ConfigurationCheckEngineProtocol {
    var results: [CheckResult]
    private(set) var lastProject: ProjectProfile?
    private(set) var lastAccount: AppleAccountProfile?
    private(set) var runCallCount = 0

    init(results: [CheckResult] = []) {
        self.results = results
    }

    func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult] {
        runCallCount += 1
        lastProject = project
        lastAccount = account
        return results
    }
}

private final class FakeUploadJobRunner: UploadJobRunning {
    var events: [UploadEvent]
    private(set) var receivedProjects: [ProjectProfile] = []
    private(set) var receivedAccounts: [AppleAccountProfile] = []

    init(events: [UploadEvent] = []) {
        self.events = events
    }

    func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile) async throws -> [UploadEvent] {
        receivedProjects.append(project)
        receivedAccounts.append(account)
        return events
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
