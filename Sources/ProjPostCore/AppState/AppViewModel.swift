import Combine
import Foundation

public protocol ProjectProfileStoreProtocol {
    func load() throws -> [ProjectProfile]
    func save(_ profiles: [ProjectProfile]) throws
}

public protocol ProjectScanning {
    func scan(projectPath: URL) async throws -> ProjectScanResult
}

public protocol ConfigurationCheckEngineProtocol {
    func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult]
}

public protocol UploadJobRunning {
    func runLocalUpload(project: ProjectProfile, account: AppleAccountProfile) async throws -> [UploadEvent]
}

public protocol ProjectMutating {
    func plan(
        project: ProjectProfile,
        targetBundleID: String?,
        targetVersion: String?,
        targetBuildNumber: String?,
        infoPlistURL: URL?
    ) throws -> ProjectMutationPlan
    func apply(_ plan: ProjectMutationPlan) throws
}

extension ProjectProfileStore: ProjectProfileStoreProtocol {}
extension ProjectScanner: ProjectScanning {}
extension ConfigurationCheckEngine: ConfigurationCheckEngineProtocol {}
extension UploadJobRunner: UploadJobRunning {}
extension ProjectMutator: ProjectMutating {}

public enum PrivateKeyStatus: Equatable {
    case missing
    case saved
    case failed
}

public enum AppViewModelError: Error, Equatable {
    case incompleteAppleAccount
    case invalidPrivateKeyPEM
}

private enum TestFlightDistributionError: Error, Equatable {
    case missingProjectFields
    case appNotFound(String)
    case buildNotFound(version: String, buildNumber: String)
}

public struct AppleAccountDraft: Equatable {
    public var id: UUID?
    public var displayName: String
    public var keyID: String
    public var issuerID: String
    public var teamID: String

    public init(id: UUID? = nil, displayName: String = "", keyID: String = "", issuerID: String = "", teamID: String = "") {
        self.id = id
        self.displayName = displayName
        self.keyID = keyID
        self.issuerID = issuerID
        self.teamID = teamID
    }

    public var isComplete: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !keyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !issuerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(profile: AppleAccountProfile) {
        self.init(
            id: profile.id,
            displayName: profile.displayName,
            keyID: profile.keyID,
            issuerID: profile.issuerID,
            teamID: profile.teamID ?? ""
        )
    }

    public func toProfile(lastVerifiedAt: Date? = nil) -> AppleAccountProfile? {
        guard isComplete else { return nil }
        let trimmedTeamID = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppleAccountProfile(
            id: id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            keyID: keyID.trimmingCharacters(in: .whitespacesAndNewlines),
            issuerID: issuerID.trimmingCharacters(in: .whitespacesAndNewlines),
            teamID: trimmedTeamID.isEmpty ? nil : trimmedTeamID,
            lastVerifiedAt: lastVerifiedAt
        )
    }
}

public final class AppViewModel: ObservableObject {
    @Published public private(set) var projects: [ProjectProfile]
    @Published public private(set) var selectedProjectID: UUID?
    @Published public private(set) var accountProfiles: [AppleAccountProfile]
    @Published public private(set) var accountProfile: AppleAccountProfile?
    @Published public var accountDraft: AppleAccountDraft
    @Published public var checkResults: [CheckResult]
    @Published public var uploadState: UploadJobState
    @Published public var uploadEvents: [UploadEvent]
    @Published public var betaReviewState: BetaReviewSubmissionState
    @Published public var testFlightDistributionState: TestFlightDistributionState
    @Published public private(set) var privateKeyStatus: PrivateKeyStatus
    @Published public private(set) var projectMutationSummary: [String]

    private let store: ProjectProfileStoreProtocol
    private let accountStore: AppleAccountProfileStoreProtocol
    private let credentialVault: CredentialVault
    private let scanner: ProjectScanning
    private let checkEngine: ConfigurationCheckEngineProtocol
    private let uploadRunner: UploadJobRunning
    private let appStoreConnectClient: AppStoreConnectClientProtocol?
    private let projectMutator: ProjectMutating
    private let jwtSigner: AppStoreConnectJWTSigner
    private var appliedProjectSettingsByID: [UUID: AppliedProjectSettings]
    private var lastCheckContext: CheckContext?

    public init(
        store: ProjectProfileStoreProtocol = ProjectProfileStore.defaultStore(),
        accountStore: AppleAccountProfileStoreProtocol = AppleAccountProfileStore.defaultStore(),
        credentialVault: CredentialVault = KeychainCredentialVault(),
        scanner: ProjectScanning? = nil,
        checkEngine: ConfigurationCheckEngineProtocol? = nil,
        uploadRunner: UploadJobRunning? = nil,
        appStoreConnectClient: AppStoreConnectClientProtocol? = nil,
        projectMutator: ProjectMutating? = nil,
        projects: [ProjectProfile] = [],
        accountProfiles: [AppleAccountProfile] = [],
        accountDraft: AppleAccountDraft = AppleAccountDraft()
    ) {
        let commandRunner = ProcessCommandRunner()
        self.store = store
        self.accountStore = accountStore
        self.credentialVault = credentialVault
        self.scanner = scanner ?? ProjectScanner(commandRunner: commandRunner)
        self.checkEngine = checkEngine ?? LiveConfigurationCheckEngine(commandRunner: commandRunner, credentialVault: credentialVault)
        self.uploadRunner = uploadRunner ?? UploadJobRunner(
            commandRunner: commandRunner,
            commandBuilder: UploadCommandBuilder(),
            credentialVault: credentialVault
        )
        self.appStoreConnectClient = appStoreConnectClient
        self.projectMutator = projectMutator ?? ProjectMutator(backupRoot: Self.defaultBackupRoot())
        self.jwtSigner = AppStoreConnectJWTSigner()
        self.projects = projects
        self.selectedProjectID = projects.first?.id
        self.accountProfiles = accountProfiles
        self.accountDraft = accountDraft
        self.accountProfile = accountDraft.toProfile()
        self.checkResults = []
        self.uploadState = .idle
        self.uploadEvents = []
        self.betaReviewState = .idle
        self.testFlightDistributionState = .idle
        self.privateKeyStatus = .missing
        self.projectMutationSummary = []
        self.appliedProjectSettingsByID = Self.appliedSettingsIndex(for: projects, treatMissingBaselineAsCurrent: true)
        self.lastCheckContext = nil

        if selectedProject?.selectedAccountID != nil {
            hydrateAccountStateFromSelectedProject()
        } else {
            refreshPrivateKeyStatus()
        }
        refreshProjectMutationState()
    }

    public var selectedProject: ProjectProfile? {
        guard let selectedProjectID else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    public var hasYellowChecks: Bool {
        checkResults.contains(where: { $0.severity == .yellow })
    }

    public var checksAreCurrent: Bool {
        guard let currentContext = currentCheckContext else { return false }
        return lastCheckContext == currentContext
    }

    public var hasCurrentYellowChecks: Bool {
        checksAreCurrent && hasYellowChecks
    }

    public var hasUnappliedProjectChanges: Bool {
        !projectMutationSummary.isEmpty
    }

    public var isOperationRunning: Bool {
        if case .running = uploadState {
            return true
        }
        if case .running = betaReviewState {
            return true
        }
        if case .loading = testFlightDistributionState {
            return true
        }
        if case .linking = testFlightDistributionState {
            return true
        }
        return false
    }

    public var isUploadInProgress: Bool {
        if case let .running(step) = uploadState {
            return step != .checkBundleAndApp
        }
        return false
    }

    public var autoCheckTrigger: String {
        guard let project = selectedProject, let account = accountProfile else { return "not-ready" }
        guard privateKeyStatus == .saved else { return "not-ready" }
        guard project.bundleID?.isEmpty == false else { return "not-ready" }
        return [
            project.id.uuidString,
            project.projectPath,
            project.workspacePath ?? "",
            project.projectFilePath ?? "",
            project.scheme ?? "",
            project.configuration,
            project.bundleID ?? "",
            project.version ?? "",
            project.buildNumber ?? "",
            project.teamID ?? "",
            account.id.uuidString,
            account.keyID,
            account.issuerID,
            account.teamID ?? ""
        ].joined(separator: "|")
    }

    public var canSubmitLatestBuildForBetaReview: Bool {
        guard !isOperationRunning else { return false }
        return canQueryLatestBuildTestFlightStatus
    }

    public var canQueryLatestBuildTestFlightStatus: Bool {
        guard let project = selectedProject, accountProfile != nil else { return false }
        return project.bundleID?.isEmpty == false &&
            project.version?.isEmpty == false &&
            project.buildNumber?.isEmpty == false
    }

    public var latestBuildStatusTrigger: String {
        guard let project = selectedProject, let account = accountProfile else { return "not-ready" }
        guard project.bundleID?.isEmpty == false,
              project.version?.isEmpty == false,
              project.buildNumber?.isEmpty == false else {
            return "not-ready"
        }
        return [
            project.id.uuidString,
            project.bundleID ?? "",
            project.version ?? "",
            project.buildNumber ?? "",
            account.id.uuidString
        ].joined(separator: "|")
    }

    public func loadProjects() throws {
        guard !isOperationRunning else { return }
        let loadedProjects = try store.load()
        let loadedAccounts = try accountStore.load()
        let previousSelection = selectedProjectID
        projects = loadedProjects
        accountProfiles = loadedAccounts
        appliedProjectSettingsByID = Self.appliedSettingsIndex(for: loadedProjects, treatMissingBaselineAsCurrent: false)
        if let previousSelection, loadedProjects.contains(where: { $0.id == previousSelection }) {
            selectedProjectID = previousSelection
        } else {
            selectedProjectID = loadedProjects.first?.id
        }
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
        refreshProjectMutationState()
    }

    public func saveProjects() throws {
        try accountStore.save(accountProfiles)
        try store.save(persistedProjects())
    }

    public func selectProject(_ id: UUID) {
        guard !isOperationRunning else { return }
        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectID = id
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
        refreshProjectMutationState()
    }

    public func deleteProject(_ id: UUID) {
        deleteProjects([id])
    }

    public func deleteProjects(_ ids: Set<UUID>) {
        guard !isOperationRunning else { return }
        guard !ids.isEmpty else { return }
        let firstDeletedIndex = projects.firstIndex(where: { ids.contains($0.id) })
        guard firstDeletedIndex != nil else { return }
        let deletedSelectedProject = selectedProjectID.map(ids.contains) ?? false

        projects.removeAll { project in
            ids.contains(project.id)
        }
        ids.forEach { appliedProjectSettingsByID.removeValue(forKey: $0) }

        if deletedSelectedProject {
            if let firstDeletedIndex, projects.indices.contains(firstDeletedIndex) {
                selectedProjectID = projects[firstDeletedIndex].id
            } else {
                selectedProjectID = projects.last?.id
            }
            invalidateChecks()
            hydrateAccountStateFromSelectedProject()
            refreshProjectMutationState()
        }

        persistState()
    }

    public func addProject(_ project: ProjectProfile) {
        guard !isOperationRunning else { return }
        projects.append(project)
        appliedProjectSettingsByID[project.id] = AppliedProjectSettings(project: project)
        selectedProjectID = project.id
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
        refreshProjectMutationState()
        persistState()
    }

    public func addProject(named name: String = "New Project", projectPath: String = "") {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = ProjectProfile(
            name: normalizedName.isEmpty ? "New Project" : normalizedName,
            projectPath: projectPath,
            workspacePath: nil,
            projectFilePath: nil,
            scheme: nil,
            configuration: "Release",
            bundleID: nil,
            version: nil,
            buildNumber: nil,
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )
        addProject(project)
    }

    public func addProjectFromDirectory(_ directoryURL: URL) async throws {
        guard !isOperationRunning else { return }
        let scanResult = try await scanner.scan(projectPath: directoryURL)
        let scannedProject = scanResult.toProjectProfile()
        await MainActor.run {
            guard !isOperationRunning else { return }
            upsertProject(scannedProject, replacingSelectedProject: false)
            if let selectedProject {
                appliedProjectSettingsByID[selectedProject.id] = AppliedProjectSettings(project: selectedProject)
            }
            invalidateChecks()
            hydrateAccountStateFromSelectedProject()
            refreshProjectMutationState()
            persistState()
        }
    }

    public func updateAccountDraft(displayName: String, keyID: String, issuerID: String, teamID: String?) {
        guard !isOperationRunning else { return }
        let existingID = accountProfile?.id ?? accountDraft.id ?? selectedProject?.selectedAccountID ?? UUID()
        accountDraft = AppleAccountDraft(
            id: existingID,
            displayName: displayName,
            keyID: keyID,
            issuerID: issuerID,
            teamID: teamID ?? ""
        )
        accountProfile = accountDraft.toProfile(lastVerifiedAt: preservedLastVerifiedAt(for: existingID))
        invalidateChecks()
        refreshPrivateKeyStatus()
    }

    public func selectAccountProfile(_ accountID: UUID?) {
        guard !isOperationRunning else { return }
        let shouldInvalidate = selectedProject?.selectedAccountID != accountID
        mutateSelectedProject(invalidateChecks: shouldInvalidate) { $0.selectedAccountID = accountID }

        guard let accountID, let storedProfile = accountProfiles.first(where: { $0.id == accountID }) else {
            accountDraft = AppleAccountDraft()
            accountProfile = nil
            if shouldInvalidate {
                invalidateChecks()
            }
            refreshPrivateKeyStatus()
            return
        }

        accountDraft = AppleAccountDraft(profile: storedProfile)
        accountProfile = storedProfile
        if shouldInvalidate {
            invalidateChecks()
        }
        refreshPrivateKeyStatus()
    }

    public func updateAutoLinkExternalGroupsAfterBetaApproval(_ value: Bool) {
        guard !isOperationRunning else { return }
        mutateSelectedProject(invalidateChecks: false) { project in
            project.autoLinkExternalGroupsAfterBetaApproval = value
        }
    }

    public func saveAccountProfile() {
        guard !isOperationRunning else { return }
        let workingAccountID = ensureWorkingAccountID()
        let lastVerifiedAt = preservedLastVerifiedAt(for: workingAccountID)
        guard let profile = accountDraft.toProfile(lastVerifiedAt: lastVerifiedAt) else {
            uploadState = .failed(message: "Complete the Apple account fields before saving.")
            return
        }

        if let index = accountProfiles.firstIndex(where: { $0.id == profile.id }) {
            accountProfiles[index] = profile
        } else {
            accountProfiles.append(profile)
        }

        accountDraft = AppleAccountDraft(profile: profile)
        accountProfile = profile
        mutateSelectedProject(invalidateChecks: false) { $0.selectedAccountID = profile.id }
        refreshPrivateKeyStatus()
        persistState(message: "Failed to save Apple account.")
    }

    public func importPrivateKey(from url: URL) throws {
        guard !isOperationRunning else { return }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            privateKeyStatus = .failed
            uploadState = .failed(message: "Failed to read the App Store Connect private key file.")
            throw error
        }
        let pem = String(decoding: data, as: UTF8.self)
        try importPrivateKeyPEM(pem)
    }

    public func importAppleAccountMetadata(from url: URL) throws {
        guard !isOperationRunning else { return }
        let metadata = try AppleAccountMetadataImporter().importMetadata(from: url)
        applyAppleAccountMetadata(metadata)
    }

    public func importAppleAccountMetadataText(_ text: String) throws {
        guard !isOperationRunning else { return }
        let metadata = try AppleAccountMetadataImporter.parse(text)
        applyAppleAccountMetadata(metadata)
    }

    public func importPrivateKeyPEM(_ privateKeyPEM: String) throws {
        guard !isOperationRunning else { return }
        let normalizedPEM = privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPEM.contains("BEGIN PRIVATE KEY"), normalizedPEM.contains("END PRIVATE KEY") else {
            privateKeyStatus = .failed
            uploadState = .failed(message: "Imported file does not contain a valid App Store Connect private key.")
            throw AppViewModelError.invalidPrivateKeyPEM
        }

        let workingAccountID = ensureWorkingAccountID()
        guard accountDraft.toProfile(lastVerifiedAt: preservedLastVerifiedAt(for: workingAccountID)) != nil else {
            privateKeyStatus = .failed
            uploadState = .failed(message: "Complete the Apple account fields before importing a private key.")
            throw AppViewModelError.incompleteAppleAccount
        }

        do {
            try credentialVault.savePrivateKey(normalizedPEM, for: workingAccountID)
            privateKeyStatus = .saved
            invalidateChecks()
        } catch {
            privateKeyStatus = .failed
            uploadState = .failed(message: "Failed to save the App Store Connect private key.")
            throw error
        }
    }

    public func updateSelectedProjectName(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.name = value }
    }

    public func updateSelectedProjectPath(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.projectPath = value }
    }

    public func updateSelectedProjectBundleID(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.bundleID = Self.normalized(value) }
    }

    public func updateSelectedProjectVersion(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.version = Self.normalized(value) }
    }

    public func updateSelectedProjectBuildNumber(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.buildNumber = Self.normalized(value) }
    }

    public func updateSelectedProjectTeamID(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.teamID = Self.normalized(value) }
    }

    public func updateSelectedProjectScheme(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.scheme = Self.normalized(value) }
    }

    public func updateSelectedProjectConfiguration(_ value: String) {
        guard !isOperationRunning else { return }
        mutateSelectedProject { $0.configuration = value.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    public func scanProject(atPath path: String) async throws {
        guard !isOperationRunning else { return }
        let nameOverride = await MainActor.run { Self.rescanNameOverride(for: selectedProject, scanningPath: path) }
        let scanResult = try await scanner.scan(projectPath: URL(fileURLWithPath: path))
        let scannedProject = scanResult.toProjectProfile(nameOverride: nameOverride)
        await MainActor.run {
            guard !isOperationRunning else { return }
            upsertProject(scannedProject, replacingSelectedProject: true)
            if let selectedProject {
                appliedProjectSettingsByID[selectedProject.id] = AppliedProjectSettings(project: selectedProject)
            }
            invalidateChecks()
            hydrateAccountStateFromSelectedProject()
            refreshProjectMutationState()
            persistState()
        }
    }

    public func runChecks() async {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            lastCheckContext = nil
            uploadState = .failed(message: "Select a project before running checks.")
            checkResults = []
            return
        }
        guard !hasUnappliedProjectChanges else {
            lastCheckContext = nil
            uploadState = .failed(message: "Apply project changes before running checks.")
            checkResults = []
            return
        }
        guard let account = accountProfile else {
            lastCheckContext = nil
            uploadState = .failed(message: "Select or enter an Apple account before running checks.")
            checkResults = []
            return
        }

        guard let currentCheckContext else {
            lastCheckContext = nil
            uploadState = .failed(message: "Select or enter an Apple account before running checks.")
            checkResults = []
            return
        }

        uploadState = .running(step: .checkBundleAndApp)
        let results = await checkEngine.run(project: project, account: account)
        checkResults = results
        lastCheckContext = currentCheckContext
        uploadState = results.blocksUpload ? .failed(message: "Configuration checks found blocking issues.") : .idle
    }

    public func runChecksAutomaticallyIfNeeded() async {
        guard autoCheckTrigger != "not-ready" else { return }
        guard !isOperationRunning else { return }
        guard !hasUnappliedProjectChanges else { return }
        guard !checksAreCurrent else { return }
        await runChecks()
    }

    public func startUpload(confirmedYellowIssues: Bool = false) async {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            uploadState = .failed(message: "Select a project before starting upload.")
            return
        }
        guard let account = accountProfile else {
            uploadState = .failed(message: "Select or enter an Apple account before uploading.")
            return
        }
        guard !hasUnappliedProjectChanges else {
            uploadState = .failed(message: "Apply project changes before uploading.")
            return
        }

        uploadEvents = []
        betaReviewState = .idle
        uploadState = .running(step: .checkBundleAndApp)

        guard let currentCheckContext else {
            uploadState = .failed(message: "Select or enter an Apple account before uploading.")
            return
        }

        let results = await checkEngine.run(project: project, account: account)
        checkResults = results
        lastCheckContext = currentCheckContext
        let checksPassed = !results.blocksUpload
        uploadEvents.append(UploadEvent(step: .checkBundleAndApp, message: Self.checkResultsConsoleMessage(results), succeeded: checksPassed))

        guard checksPassed else {
            uploadState = .failed(message: "Upload blocked by configuration issues. Resolve red checks before uploading.")
            return
        }

        uploadState = .running(step: .archive)

        do {
            let events = try await uploadRunner.runLocalUpload(project: project, account: account)
            uploadEvents.append(contentsOf: events)
            uploadState = .succeeded(message: "Upload finished successfully.")
            applyLastUploadSummary(success: true, message: events.last?.message ?? "Upload finished successfully.")
        } catch {
            uploadState = .failed(message: "Upload failed: \(error)")
            applyLastUploadSummary(success: false, message: "Upload failed: \(error)")
        }
    }

    public func submitLatestBuildForBetaReview() async {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            betaReviewState = .failed(message: "Select a project before submitting TestFlight review.")
            return
        }
        guard let account = accountProfile else {
            betaReviewState = .failed(message: "Select an Apple account before submitting TestFlight review.")
            return
        }
        guard let bundleID = project.bundleID, !bundleID.isEmpty,
              let version = project.version, !version.isEmpty,
              let buildNumber = project.buildNumber, !buildNumber.isEmpty else {
            betaReviewState = .failed(message: "Bundle ID, version, and build number are required before submitting review.")
            return
        }

        betaReviewState = .running
        do {
            let client = appStoreConnectClient(for: account)
            guard let app = try await client.fetchApp(bundleID: bundleID) else {
                betaReviewState = .failed(message: "App Store Connect app not found for \(bundleID).")
                return
            }
            guard let build = try await client.fetchBuilds(appID: app.id, appVersion: version, buildNumber: buildNumber).first else {
                betaReviewState = .failed(message: "Uploaded build \(version) (\(buildNumber)) was not found in App Store Connect yet.")
                return
            }
            if let processingState = build.processingState, processingState != "VALID" {
                betaReviewState = .failed(message: "Build \(version) (\(buildNumber)) is \(processingState). Wait until Apple processing is VALID.")
                return
            }

            let submission = try await client.submitBetaReview(buildID: build.id)
            let stateText = Self.readableBetaReviewState(submission.betaReviewState) ?? "Submitted"
            betaReviewState = .succeeded(message: "Submitted to TestFlight review. State: \(stateText)")
        } catch {
            betaReviewState = .failed(message: "Submit to TestFlight review failed: \(error)")
        }
    }

    public func refreshLatestBuildTestFlightStatusIfNeeded() async {
        guard latestBuildStatusTrigger != "not-ready" else { return }
        guard !isOperationRunning else { return }
        await refreshLatestBuildTestFlightStatus()
    }

    public func refreshLatestBuildTestFlightStatus() async {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            betaReviewState = .failed(message: "Select a project before refreshing TestFlight status.")
            return
        }
        guard let account = accountProfile else {
            betaReviewState = .failed(message: "Select an Apple account before refreshing TestFlight status.")
            return
        }
        guard let bundleID = project.bundleID, !bundleID.isEmpty,
              let version = project.version, !version.isEmpty,
              let buildNumber = project.buildNumber, !buildNumber.isEmpty else {
            betaReviewState = .failed(message: "Bundle ID, version, and build number are required before refreshing status.")
            return
        }

        betaReviewState = .running
        testFlightDistributionState = .loading
        do {
            let loaded = try await loadLatestBuildDistribution(project: project, account: account)
            let snapshot = loaded.snapshot
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

            if linkFailureCount > 0 {
                betaReviewState = .failed(message: "Linked external groups with \(linkFailureCount) failure.")
            } else if let processingState = snapshot.processingState, processingState != "VALID" {
                betaReviewState = .succeeded(message: "TestFlight status: \(snapshot.betaReviewStateText). Build processing: \(processingState)")
            } else {
                betaReviewState = .succeeded(message: "TestFlight status: \(snapshot.betaReviewStateText)")
            }
            testFlightDistributionState = .loaded(finalSnapshot)
        } catch {
            let message = Self.testFlightDistributionErrorMessage(error)
            betaReviewState = .failed(message: message)
            testFlightDistributionState = .failed(message: message)
        }
    }

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

    public func applyProjectChanges() throws {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            uploadState = .failed(message: "Select a project before applying project changes.")
            return
        }
        guard hasUnappliedProjectChanges else { return }

        let applied = appliedProjectSettingsByID[project.id] ?? AppliedProjectSettings(project: project)
        var currentProject = project
        currentProject.bundleID = applied.bundleID
        currentProject.version = applied.version
        currentProject.buildNumber = applied.buildNumber

        let plan = try projectMutator.plan(
            project: currentProject,
            targetBundleID: project.bundleID,
            targetVersion: project.version,
            targetBuildNumber: project.buildNumber,
            infoPlistURL: nil
        )
        try projectMutator.apply(plan)
        appliedProjectSettingsByID[project.id] = AppliedProjectSettings(project: project)
        invalidateChecks()
        refreshProjectMutationState()
        persistState()
    }

    private func upsertProject(_ project: ProjectProfile, replacingSelectedProject: Bool) {
        if replacingSelectedProject, let selectedProjectID, let index = projects.firstIndex(where: { $0.id == selectedProjectID }) {
            var updated = project
            updated.id = selectedProjectID
            updated.name = projects[index].name.isEmpty ? project.name : projects[index].name
            updated.selectedAccountID = projects[index].selectedAccountID
            updated.lastUpload = projects[index].lastUpload
            updated.autoLinkExternalGroupsAfterBetaApproval = projects[index].autoLinkExternalGroupsAfterBetaApproval
            projects[index] = updated
        } else if let index = projects.firstIndex(where: { $0.projectPath == project.projectPath }) {
            var updated = project
            updated.id = projects[index].id
            updated.selectedAccountID = projects[index].selectedAccountID
            updated.lastUpload = projects[index].lastUpload
            updated.autoLinkExternalGroupsAfterBetaApproval = projects[index].autoLinkExternalGroupsAfterBetaApproval
            projects[index] = updated
            selectedProjectID = updated.id
        } else {
            var newProject = project
            newProject.selectedAccountID = nil
            projects.append(newProject)
            selectedProjectID = newProject.id
        }
    }

    private func applyAppleAccountMetadata(_ metadata: AppleAccountMetadata) {
        updateAccountDraft(
            displayName: accountDraft.displayName,
            keyID: metadata.keyID,
            issuerID: metadata.issuerID,
            teamID: metadata.teamID ?? accountDraft.teamID
        )
    }

    private func mutateSelectedProject(invalidateChecks: Bool = true, _ mutate: (inout ProjectProfile) -> Void) {
        guard let selectedProjectID, let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        let previousProject = projects[index]
        mutate(&projects[index])
        guard projects[index] != previousProject else { return }
        if invalidateChecks {
            self.invalidateChecks()
        }
        refreshProjectMutationState()
        persistState()
    }

    private var currentCheckContext: CheckContext? {
        guard let project = selectedProject, let account = accountProfile else { return nil }
        return CheckContext(
            project: ProjectSnapshot(project: project),
            account: AccountSnapshot(account: account),
            privateKeyStatus: privateKeyStatus
        )
    }

    private func invalidateChecks() {
        lastCheckContext = nil
        clearRunState()
    }

    private func clearRunState() {
        checkResults = []
        uploadEvents = []
        uploadState = .idle
        betaReviewState = .idle
        testFlightDistributionState = .idle
    }

    private static func checkResultsConsoleMessage(_ results: [CheckResult]) -> String {
        guard !results.isEmpty else {
            return "[OK] Configuration checks completed with no issues."
        }

        return results.map { result in
            let prefix: String
            switch result.severity {
            case .green:
                prefix = "[OK]"
            case .yellow:
                prefix = "[WARN]"
            case .red:
                prefix = "[BLOCKED]"
            }
            return "\(prefix) \(result.title)\n\(result.message)"
        }.joined(separator: "\n\n")
    }

    private static func readableBetaReviewState(_ state: String?) -> String? {
        guard let state else { return nil }
        switch state {
        case "WAITING_FOR_REVIEW":
            return "Waiting for Review"
        case "IN_REVIEW":
            return "In Review"
        case "APPROVED":
            return "Approved"
        case "REJECTED":
            return "Rejected"
        default:
            return state
        }
    }

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

    private var currentDistributionSnapshot: TestFlightDistributionSnapshot? {
        switch testFlightDistributionState {
        case .loaded(let snapshot):
            return snapshot
        case .linking(let snapshot):
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
        var associatedIDs = Set<String>()
        for group in allGroups {
            let groupBuilds = try await client.fetchBuildsForBetaGroup(betaGroupID: group.id)
            if groupBuilds.contains(where: { $0.id == build.id }) {
                associatedIDs.insert(group.id)
            }
        }
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

    private func persistState(message: String = "Failed to save changes.") {
        do {
            try accountStore.save(accountProfiles)
            try store.save(persistedProjects())
        } catch {
            uploadState = .failed(message: "\(message) \(error)")
        }
    }

    private func refreshProjectMutationState() {
        guard let project = selectedProject else {
            projectMutationSummary = []
            return
        }

        let applied = appliedProjectSettingsByID[project.id] ?? AppliedProjectSettings(project: project)
        var summary: [String] = []
        appendMutationSummary(&summary, label: "Bundle ID", old: applied.bundleID, new: project.bundleID)
        appendMutationSummary(&summary, label: "Version", old: applied.version, new: project.version)
        appendMutationSummary(&summary, label: "Build Number", old: applied.buildNumber, new: project.buildNumber)
        projectMutationSummary = summary
    }

    private func appendMutationSummary(_ summary: inout [String], label: String, old: String?, new: String?) {
        guard let new else { return }
        guard old != new else { return }
        summary.append("\(label): \(old ?? "-") -> \(new)")
    }

    private func hydrateAccountStateFromSelectedProject() {
        guard let selectedAccountID = selectedProject?.selectedAccountID else {
            accountDraft = AppleAccountDraft()
            accountProfile = nil
            refreshPrivateKeyStatus()
            return
        }

        guard let storedProfile = accountProfiles.first(where: { $0.id == selectedAccountID }) else {
            accountDraft = AppleAccountDraft(id: selectedAccountID)
            accountProfile = nil
            refreshPrivateKeyStatus()
            return
        }

        accountDraft = AppleAccountDraft(profile: storedProfile)
        accountProfile = storedProfile
        refreshPrivateKeyStatus()
    }

    private func preservedLastVerifiedAt(for accountID: UUID?) -> Date? {
        guard let accountID else { return nil }
        return accountProfiles.first(where: { $0.id == accountID })?.lastVerifiedAt
    }

    private func ensureWorkingAccountID() -> UUID {
        if let existingID = accountDraft.id ?? accountProfile?.id ?? selectedProject?.selectedAccountID {
            accountDraft.id = existingID
            return existingID
        }

        let generatedID = UUID()
        accountDraft.id = generatedID
        return generatedID
    }

    private func refreshPrivateKeyStatus() {
        let accountID = accountProfile?.id ?? accountDraft.id
        guard let accountID else {
            privateKeyStatus = .missing
            return
        }

        do {
            _ = try credentialVault.privateKey(for: accountID)
            privateKeyStatus = .saved
        } catch CredentialVaultError.itemNotFound {
            privateKeyStatus = .missing
        } catch {
            privateKeyStatus = .failed
        }
    }

    private func appStoreConnectClient(for account: AppleAccountProfile) -> AppStoreConnectClientProtocol {
        if let appStoreConnectClient {
            return appStoreConnectClient
        }

        return AppStoreConnectClient { [credentialVault, jwtSigner] in
            let privateKey = try credentialVault.privateKey(for: account.id)
            return try jwtSigner.makeJWT(account: account, privateKeyPEM: privateKey)
        }
    }

    private func applyLastUploadSummary(success: Bool, message: String) {
        mutateSelectedProject(invalidateChecks: false) { project in
            project.lastUpload = UploadSummary(
                version: project.version ?? "-",
                buildNumber: project.buildNumber ?? "-",
                uploadedAt: Date(),
                succeeded: success,
                message: message
            )
        }
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func rescanNameOverride(for project: ProjectProfile?, scanningPath: String) -> String? {
        guard let project else { return nil }
        let currentFolderName = URL(fileURLWithPath: project.projectPath).lastPathComponent
        let scanningFolderName = URL(fileURLWithPath: scanningPath).lastPathComponent
        if project.name == currentFolderName || project.name == scanningFolderName {
            return nil
        }
        return project.name
    }

    private static func defaultBackupRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ProjPost", isDirectory: true).appendingPathComponent("ProjectBackups", isDirectory: true)
    }

    private func persistedProjects() -> [ProjectProfile] {
        projects.map { project in
            var persisted = project
            persisted.appliedSettings = appliedProjectSettingsByID[project.id]?.persisted
            return persisted
        }
    }

    private static func appliedSettingsIndex(
        for projects: [ProjectProfile],
        treatMissingBaselineAsCurrent: Bool
    ) -> [UUID: AppliedProjectSettings] {
        Dictionary(uniqueKeysWithValues: projects.map { project in
            let applied: AppliedProjectSettings
            if let persisted = project.appliedSettings {
                applied = AppliedProjectSettings(persisted: persisted)
            } else if treatMissingBaselineAsCurrent {
                applied = AppliedProjectSettings(project: project)
            } else {
                applied = .unknown
            }
            return (project.id, applied)
        })
    }
}

private struct AppliedProjectSettings: Equatable {
    let bundleID: String?
    let version: String?
    let buildNumber: String?

    static let unknown = AppliedProjectSettings(bundleID: nil, version: nil, buildNumber: nil)

    init(project: ProjectProfile) {
        self.bundleID = project.bundleID
        self.version = project.version
        self.buildNumber = project.buildNumber
    }

    init(persisted: ProjectAppliedSettings) {
        self.bundleID = persisted.bundleID
        self.version = persisted.version
        self.buildNumber = persisted.buildNumber
    }

    init(bundleID: String?, version: String?, buildNumber: String?) {
        self.bundleID = bundleID
        self.version = version
        self.buildNumber = buildNumber
    }

    var persisted: ProjectAppliedSettings {
        ProjectAppliedSettings(bundleID: bundleID, version: version, buildNumber: buildNumber)
    }
}

private struct CheckContext: Equatable {
    let project: ProjectSnapshot
    let account: AccountSnapshot
    let privateKeyStatus: PrivateKeyStatus
}

private struct ProjectSnapshot: Equatable {
    let id: UUID
    let name: String
    let projectPath: String
    let workspacePath: String?
    let projectFilePath: String?
    let scheme: String?
    let configuration: String
    let bundleID: String?
    let version: String?
    let buildNumber: String?
    let teamID: String?

    init(project: ProjectProfile) {
        self.id = project.id
        self.name = project.name
        self.projectPath = project.projectPath
        self.workspacePath = project.workspacePath
        self.projectFilePath = project.projectFilePath
        self.scheme = project.scheme
        self.configuration = project.configuration
        self.bundleID = project.bundleID
        self.version = project.version
        self.buildNumber = project.buildNumber
        self.teamID = project.teamID
    }
}

private struct AccountSnapshot: Equatable {
    let id: UUID
    let displayName: String
    let keyID: String
    let issuerID: String
    let teamID: String?
    let lastVerifiedAt: Date?

    init(account: AppleAccountProfile) {
        self.id = account.id
        self.displayName = account.displayName
        self.keyID = account.keyID
        self.issuerID = account.issuerID
        self.teamID = account.teamID
        self.lastVerifiedAt = account.lastVerifiedAt
    }
}

private final class LiveConfigurationCheckEngine: ConfigurationCheckEngineProtocol {
    private let commandRunner: CommandRunning
    private let credentialVault: CredentialVault
    private let jwtSigner: AppStoreConnectJWTSigner

    init(
        commandRunner: CommandRunning = ProcessCommandRunner(),
        credentialVault: CredentialVault = KeychainCredentialVault(),
        jwtSigner: AppStoreConnectJWTSigner = AppStoreConnectJWTSigner()
    ) {
        self.commandRunner = commandRunner
        self.credentialVault = credentialVault
        self.jwtSigner = jwtSigner
    }

    func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult] {
        let client = AppStoreConnectClient { [credentialVault, jwtSigner] in
            let privateKey = try credentialVault.privateKey(for: account.id)
            return try jwtSigner.makeJWT(account: account, privateKeyPEM: privateKey)
        }
        let engine = ConfigurationCheckEngine(
            environment: XcodeEnvironmentChecker(commandRunner: commandRunner),
            appStoreConnect: client
        )
        return await engine.run(project: project, account: account)
    }
}
