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
    func run(project: ProjectProfile, account: AppleAccountProfile, language: AppLanguage) async -> [CheckResult]
}

public extension ConfigurationCheckEngineProtocol {
    func run(project: ProjectProfile, account: AppleAccountProfile, language: AppLanguage) async -> [CheckResult] {
        await run(project: project, account: account)
    }
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

private enum AppStoreReviewError: Error, Equatable {
    case missingProjectFields
    case appNotFound(String)
    case versionNotFound(String)
    case buildNotSelected
    case versionNotLoaded
    case noActiveSubmissionToWithdraw
    case selectedBuildNotBound
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
    @Published public var appStoreReviewState: AppStoreReviewState
    @Published public var updateState: AppUpdateState
    @Published public var language: AppLanguage
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
    private let updateChecker: AppUpdateChecking
    private let jwtSigner: AppStoreConnectJWTSigner
    private var appliedProjectSettingsByID: [UUID: AppliedProjectSettings]
    private var lastCheckContext: CheckContext?
    private var hasCheckedForUpdates: Bool

    public init(
        store: ProjectProfileStoreProtocol = ProjectProfileStore.defaultStore(),
        accountStore: AppleAccountProfileStoreProtocol = AppleAccountProfileStore.defaultStore(),
        credentialVault: CredentialVault = KeychainCredentialVault(),
        scanner: ProjectScanning? = nil,
        checkEngine: ConfigurationCheckEngineProtocol? = nil,
        uploadRunner: UploadJobRunning? = nil,
        appStoreConnectClient: AppStoreConnectClientProtocol? = nil,
        projectMutator: ProjectMutating? = nil,
        updateChecker: AppUpdateChecking? = nil,
        projects: [ProjectProfile] = [],
        accountProfiles: [AppleAccountProfile] = [],
        accountDraft: AppleAccountDraft = AppleAccountDraft(),
        language: AppLanguage = .english
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
        self.updateChecker = updateChecker ?? AppUpdateChecker()
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
        self.appStoreReviewState = .idle
        self.updateState = .idle
        self.language = language
        self.privateKeyStatus = .missing
        self.projectMutationSummary = []
        self.appliedProjectSettingsByID = Self.appliedSettingsIndex(for: projects, treatMissingBaselineAsCurrent: true)
        self.lastCheckContext = nil
        self.hasCheckedForUpdates = false

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

    public var availableUpdate: AppReleaseInfo? {
        guard case let .available(_, latestRelease) = updateState else { return nil }
        return latestRelease
    }

    private var strings: AppStrings {
        AppStrings(language: language)
    }

    public func updateLanguage(_ language: AppLanguage) {
        self.language = language
        relocalizeDistributionState()
        refreshBetaReviewStatusMessageFromSnapshot()
        refreshProjectMutationState()
    }

    public func checkForUpdatesIfNeeded() async {
        guard !hasCheckedForUpdates else { return }
        hasCheckedForUpdates = true
        updateState = .checking
        do {
            switch try await updateChecker.checkForUpdate() {
            case let .available(currentVersion, latestRelease):
                updateState = .available(currentVersion: currentVersion, latestRelease: latestRelease)
            case .upToDate:
                updateState = .idle
            }
        } catch {
            updateState = .idle
        }
    }

    public func dismissAvailableUpdate() {
        if case .available = updateState {
            updateState = .idle
        }
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
        if case .loading = appStoreReviewState {
            return true
        }
        if case .preparing = appStoreReviewState {
            return true
        }
        if case .binding = appStoreReviewState {
            return true
        }
        if case .saving = appStoreReviewState {
            return true
        }
        if case .submitting = appStoreReviewState {
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

    public var canQueryAppStoreReviewStatus: Bool {
        guard let project = selectedProject, accountProfile != nil else { return false }
        return project.bundleID?.isEmpty == false &&
            project.version?.isEmpty == false
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
            if !value {
                project.autoLinkExternalGroupIDsAfterBetaApproval.removeAll()
            }
        }
    }

    public func updateAutoLinkExternalGroup(_ groupID: String, isEnabled: Bool) {
        guard !isOperationRunning else { return }
        mutateSelectedProject(invalidateChecks: false) { project in
            project.autoLinkExternalGroupsAfterBetaApproval = false
            if isEnabled {
                project.autoLinkExternalGroupIDsAfterBetaApproval.insert(groupID)
            } else {
                project.autoLinkExternalGroupIDsAfterBetaApproval.remove(groupID)
            }
        }
    }

    public func saveAccountProfile() {
        guard !isOperationRunning else { return }
        let workingAccountID = ensureWorkingAccountID()
        let lastVerifiedAt = preservedLastVerifiedAt(for: workingAccountID)
        guard let profile = accountDraft.toProfile(lastVerifiedAt: lastVerifiedAt) else {
            uploadState = .failed(message: strings.completeAppleAccountFieldsBeforeSaving)
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
        persistState(message: strings.failedToSaveAppleAccount)
    }

    public func importPrivateKey(from url: URL) throws {
        guard !isOperationRunning else { return }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            privateKeyStatus = .failed
            uploadState = .failed(message: strings.failedToReadPrivateKeyFile)
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
            uploadState = .failed(message: strings.invalidPrivateKeyFile)
            throw AppViewModelError.invalidPrivateKeyPEM
        }

        let workingAccountID = ensureWorkingAccountID()
        guard accountDraft.toProfile(lastVerifiedAt: preservedLastVerifiedAt(for: workingAccountID)) != nil else {
            privateKeyStatus = .failed
            uploadState = .failed(message: strings.completeAppleAccountBeforeImportingPrivateKey)
            throw AppViewModelError.incompleteAppleAccount
        }

        do {
            try credentialVault.savePrivateKey(normalizedPEM, for: workingAccountID)
            privateKeyStatus = .saved
            invalidateChecks()
        } catch {
            privateKeyStatus = .failed
            uploadState = .failed(message: strings.failedToSavePrivateKey)
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
            uploadState = .failed(message: strings.selectProjectBeforeRunningChecks)
            checkResults = []
            return
        }
        guard !hasUnappliedProjectChanges else {
            lastCheckContext = nil
            uploadState = .failed(message: strings.applyProjectChangesBeforeRunningChecks)
            checkResults = []
            return
        }
        guard let account = accountProfile else {
            lastCheckContext = nil
            uploadState = .failed(message: strings.selectOrEnterAppleAccountBeforeRunningChecks)
            checkResults = []
            return
        }

        guard let currentCheckContext else {
            lastCheckContext = nil
            uploadState = .failed(message: strings.selectOrEnterAppleAccountBeforeRunningChecks)
            checkResults = []
            return
        }

        uploadState = .running(step: .checkBundleAndApp)
        let results = await checkEngine.run(project: project, account: account, language: language)
        checkResults = results
        lastCheckContext = currentCheckContext
        uploadState = results.blocksUpload ? .failed(message: strings.configurationChecksFoundBlockingIssues) : .idle
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
            uploadState = .failed(message: strings.selectProjectBeforeUpload)
            return
        }
        guard let account = accountProfile else {
            uploadState = .failed(message: strings.selectOrEnterAppleAccountBeforeUploading)
            return
        }
        guard !hasUnappliedProjectChanges else {
            uploadState = .failed(message: strings.applyProjectChangesBeforeUploading)
            return
        }

        uploadEvents = []
        betaReviewState = .idle
        uploadState = .running(step: .checkBundleAndApp)

        guard let currentCheckContext else {
            uploadState = .failed(message: strings.selectOrEnterAppleAccountBeforeUploading)
            return
        }

        let results = await checkEngine.run(project: project, account: account, language: language)
        checkResults = results
        lastCheckContext = currentCheckContext
        let checksPassed = !results.blocksUpload
        uploadEvents.append(UploadEvent(step: .checkBundleAndApp, message: checkResultsConsoleMessage(results), succeeded: checksPassed))

        guard checksPassed else {
            uploadState = .failed(message: strings.uploadBlockedByConfigurationIssues)
            return
        }

        uploadState = .running(step: .archive)

        do {
            let events = try await uploadRunner.runLocalUpload(project: project, account: account)
            uploadEvents.append(contentsOf: events)
            uploadState = .succeeded(message: strings.uploadFinishedSuccessfully)
            applyLastUploadSummary(success: true, message: events.last?.message ?? strings.uploadFinishedSuccessfully)
        } catch {
            let message = strings.uploadFailed(error)
            uploadState = .failed(message: message)
            applyLastUploadSummary(success: false, message: message)
        }
    }

    public func submitLatestBuildForBetaReview() async {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            betaReviewState = .failed(message: strings.selectProjectBeforeSubmittingReview)
            return
        }
        guard let account = accountProfile else {
            betaReviewState = .failed(message: strings.selectAppleAccountBeforeSubmittingReview)
            return
        }
        guard let bundleID = project.bundleID, !bundleID.isEmpty,
              let version = project.version, !version.isEmpty,
              let buildNumber = project.buildNumber, !buildNumber.isEmpty else {
            betaReviewState = .failed(message: strings.bundleVersionBuildRequiredBeforeSubmittingReview)
            return
        }

        betaReviewState = .running
        do {
            let client = appStoreConnectClient(for: account)
            guard let app = try await client.fetchApp(bundleID: bundleID) else {
                betaReviewState = .failed(message: strings.appStoreConnectAppNotFound(bundleID))
                return
            }
            guard let build = try await client.fetchBuilds(appID: app.id, appVersion: version, buildNumber: buildNumber).first else {
                betaReviewState = .failed(message: strings.uploadedBuildNotFound(version: version, buildNumber: buildNumber))
                return
            }
            if let processingState = build.processingState, processingState != "VALID" {
                betaReviewState = .failed(message: strings.buildProcessingNotValid(version: version, buildNumber: buildNumber, processingState: processingState))
                return
            }

            let submission = try await client.submitBetaReview(buildID: build.id)
            let stateText = readableBetaReviewState(submission.betaReviewState) ?? strings.betaReviewStatusSubmitted
            betaReviewState = .succeeded(message: strings.submittedToTestFlightReview(state: stateText))
        } catch {
            betaReviewState = .failed(message: strings.submitToTestFlightReviewFailed(error))
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
            betaReviewState = .failed(message: strings.selectProjectBeforeRefreshingTestFlightStatus)
            return
        }
        guard let account = accountProfile else {
            betaReviewState = .failed(message: strings.selectAppleAccountBeforeRefreshingTestFlightStatus)
            return
        }
        guard let bundleID = project.bundleID, !bundleID.isEmpty,
              let version = project.version, !version.isEmpty,
              let buildNumber = project.buildNumber, !buildNumber.isEmpty else {
            betaReviewState = .failed(message: strings.bundleVersionBuildRequiredBeforeRefreshingStatus)
            return
        }

        betaReviewState = .running
        testFlightDistributionState = .loading
        do {
            let loaded = try await loadLatestBuildDistribution(project: project, account: account)
            let snapshot = loaded.snapshot
            var finalSnapshot = snapshot
            var linkFailureCount = 0
            let autoGroupIDs = project.autoLinkExternalGroupIDsAfterBetaApproval
            if !autoGroupIDs.isEmpty,
               snapshot.betaReviewState == "APPROVED",
               !snapshot.externalGroups.isEmpty {
                testFlightDistributionState = .linking(snapshot)
                let result = await linkExternalGroups(snapshot: snapshot, client: loaded.client, targetGroupIDs: autoGroupIDs)
                finalSnapshot = result.snapshot
                linkFailureCount = result.failureCount
            }

            if linkFailureCount > 0 {
                betaReviewState = .failed(message: strings.linkedExternalGroupsWithFailureCount(linkFailureCount))
            } else if let processingState = snapshot.processingState, processingState != "VALID" {
                betaReviewState = .succeeded(message: strings.testFlightStatus(snapshot.betaReviewStateText, processingState: processingState))
            } else {
                betaReviewState = .succeeded(message: strings.testFlightStatus(snapshot.betaReviewStateText))
            }
            testFlightDistributionState = .loaded(finalSnapshot)
        } catch {
            let message = testFlightDistributionErrorMessage(error)
            betaReviewState = .failed(message: message)
            testFlightDistributionState = .failed(message: message)
        }
    }

    public func linkExternalGroupsForLatestBuild() async {
        await linkExternalGroupsForLatestBuild(targetGroupID: nil)
    }

    public func linkExternalGroupForLatestBuild(groupID: String) async {
        await linkExternalGroupsForLatestBuild(targetGroupID: groupID)
    }

    public func refreshAppStoreReviewStatus() async {
        guard !isOperationRunning else { return }
        appStoreReviewState = .loading
        do {
            let loaded = try await loadAppStoreReviewSnapshot(createIfMissing: false)
            appStoreReviewState = .loaded(loaded.snapshot)
        } catch {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(error), snapshot: currentAppStoreReviewSnapshot)
        }
    }

    public func prepareAppStoreReviewVersion() async {
        guard !isOperationRunning else { return }
        appStoreReviewState = .preparing(currentAppStoreReviewSnapshot)
        do {
            let loaded = try await loadAppStoreReviewSnapshot(createIfMissing: true)
            appStoreReviewState = .loaded(loaded.snapshot)
        } catch {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(error), snapshot: currentAppStoreReviewSnapshot)
        }
    }

    public func selectAppStoreReviewBuild(_ buildID: String?) {
        guard !isOperationRunning else { return }
        guard var snapshot = currentAppStoreReviewSnapshot else { return }
        snapshot.selectedBuildID = buildID
        appStoreReviewState = .loaded(snapshot)
    }

    public func bindSelectedAppStoreReviewBuild() async {
        guard !isOperationRunning else { return }
        guard var snapshot = currentAppStoreReviewSnapshot else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: nil)
            return
        }
        guard let buildID = snapshot.selectedBuildID else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.buildNotSelected), snapshot: snapshot)
            return
        }
        guard let account = accountProfile else {
            appStoreReviewState = .failed(message: strings.selectAppleAccountBeforeRefreshingTestFlightStatus, snapshot: snapshot)
            return
        }

        appStoreReviewState = .binding(snapshot)
        do {
            let client = appStoreConnectClient(for: account)
            try await client.updateAppStoreVersionBuild(appStoreVersionID: snapshot.appStoreVersionID, buildID: buildID)
            snapshot.boundBuildID = buildID
            snapshot.builds = snapshot.builds.map { build in
                AppStoreReviewBuildOption(
                    id: build.id,
                    buildNumber: build.buildNumber,
                    processingState: build.processingState,
                    isBound: build.id == buildID
                )
            }
            appStoreReviewState = .loaded(snapshot)
        } catch {
            appStoreReviewState = .failed(message: strings.appStoreReviewBindBuildFailed(error), snapshot: snapshot)
        }
    }

    public func saveAppStoreReviewAdvancedDraft(_ draft: AppStoreReviewAdvancedDraft) async {
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
            for localizationUpdate in draft.localizationUpdates {
                _ = try await client.updateAppStoreVersionLocalization(
                    localizationID: localizationUpdate.localizationID,
                    update: localizationUpdate.update
                )
            }

            if let reviewDetailID = draft.reviewDetailID, let reviewDetailUpdate = draft.reviewDetailUpdate {
                _ = try await client.updateAppStoreReviewDetail(
                    reviewDetailID: reviewDetailID,
                    update: reviewDetailUpdate
                )
            }

            let loaded = try await loadAppStoreReviewSnapshot(createIfMissing: false)
            appStoreReviewState = .loaded(loaded.snapshot)
        } catch {
            appStoreReviewState = .failed(message: strings.appStoreReviewSaveFailed(error), snapshot: snapshot)
        }
    }

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
                snapshot.builds = snapshot.builds.map { build in
                    AppStoreReviewBuildOption(
                        id: build.id,
                        buildNumber: build.buildNumber,
                        processingState: build.processingState,
                        isBound: build.id == selectedBuildID
                    )
                }
            }

            let submissionID: String
            // Retry-after-failed-submit path: a dangling READY_FOR_REVIEW submission means its item was
            // already created before an earlier failure, so reuse it instead of creating a second one.
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

    public func cancelAppStoreReview() async {
        guard !isOperationRunning else { return }
        guard let snapshot = currentAppStoreReviewSnapshot else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.versionNotLoaded), snapshot: nil)
            return
        }
        guard let submissionID = snapshot.reviewSubmissionID else {
            appStoreReviewState = .failed(message: appStoreReviewErrorMessage(AppStoreReviewError.noActiveSubmissionToWithdraw), snapshot: snapshot)
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

    private func linkExternalGroupsForLatestBuild(targetGroupID: String?) async {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            testFlightDistributionState = .failed(message: strings.selectProjectBeforeLinkingExternalGroups)
            return
        }
        guard let account = accountProfile else {
            testFlightDistributionState = .failed(message: strings.selectAppleAccountBeforeLinkingExternalGroups)
            return
        }

        testFlightDistributionState = .linking(currentDistributionSnapshot)
        do {
            let loaded = try await loadLatestBuildDistribution(project: project, account: account)
            let targetGroupIDs = targetGroupID.map { Set([$0]) }
            let linkedSnapshot = await linkExternalGroups(snapshot: loaded.snapshot, client: loaded.client, targetGroupIDs: targetGroupIDs)
            testFlightDistributionState = .loaded(linkedSnapshot.snapshot)
            betaReviewState = linkedSnapshot.failureCount == 0
                ? .succeeded(message: targetGroupID == nil ? strings.externalTestFlightGroupsLinked : strings.externalTestFlightGroupLinked)
                : .failed(message: strings.linkedExternalGroupsWithFailureCount(linkedSnapshot.failureCount))
        } catch {
            let message = testFlightDistributionErrorMessage(error)
            testFlightDistributionState = .failed(message: message)
            betaReviewState = .failed(message: message)
        }
    }

    public func applyProjectChanges() throws {
        guard !isOperationRunning else { return }
        guard let project = selectedProject else {
            uploadState = .failed(message: strings.selectProjectBeforeApplyingProjectChanges)
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
        appStoreReviewState = .idle
    }

    private func checkResultsConsoleMessage(_ results: [CheckResult]) -> String {
        guard !results.isEmpty else {
            return strings.configurationChecksCompletedNoIssues
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

    private func readableBetaReviewState(_ state: String?) -> String? {
        guard let state else { return nil }
        switch state {
        case "WAITING_FOR_REVIEW":
            return strings.betaReviewStatusWaitingForReview
        case "IN_REVIEW":
            return strings.betaReviewStatusInReview
        case "APPROVED":
            return strings.betaReviewStatusApproved
        case "REJECTED":
            return strings.betaReviewStatusRejected
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

    private var currentAppStoreReviewSnapshot: AppStoreReviewSnapshot? {
        switch appStoreReviewState {
        case .loaded(let snapshot):
            return snapshot
        case .preparing(let snapshot):
            return snapshot
        case .binding(let snapshot):
            return snapshot
        case .saving(let snapshot):
            return snapshot
        case .submitting(let snapshot):
            return snapshot
        case .succeeded(_, let snapshot):
            return snapshot
        case .failed(_, let snapshot):
            return snapshot
        default:
            return nil
        }
    }

    private func relocalizeDistributionState() {
        switch testFlightDistributionState {
        case .loaded(let snapshot):
            testFlightDistributionState = .loaded(localizedDistributionSnapshot(snapshot))
        case .linking(let snapshot):
            testFlightDistributionState = .linking(snapshot.map(localizedDistributionSnapshot))
        default:
            break
        }
    }

    private func localizedDistributionSnapshot(_ snapshot: TestFlightDistributionSnapshot) -> TestFlightDistributionSnapshot {
        var updated = snapshot
        updated.betaReviewStateText = readableBetaReviewState(snapshot.betaReviewState) ?? strings.betaReviewStatusNotSubmitted
        return updated
    }

    private func refreshBetaReviewStatusMessageFromSnapshot() {
        guard case .succeeded = betaReviewState, let snapshot = currentDistributionSnapshot else { return }
        if let processingState = snapshot.processingState, processingState != "VALID" {
            betaReviewState = .succeeded(message: strings.testFlightStatus(snapshot.betaReviewStateText, processingState: processingState))
        } else {
            betaReviewState = .succeeded(message: strings.testFlightStatus(snapshot.betaReviewStateText))
        }
    }

    private func linkExternalGroups(
        snapshot: TestFlightDistributionSnapshot,
        client: AppStoreConnectClientProtocol,
        targetGroupIDs: Set<String>? = nil
    ) async -> (snapshot: TestFlightDistributionSnapshot, failureCount: Int) {
        var updated = snapshot
        var failureCount = 0
        var linkedGroups: [TestFlightDistributionGroup] = []

        for group in snapshot.externalGroups {
            guard targetGroupIDs?.contains(group.id) ?? true else {
                linkedGroups.append(group)
                continue
            }
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
        let betaReviewSubmission = try await client.fetchBetaReviewSubmission(buildID: build.id)

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
        let betaReviewState = betaReviewSubmission?.betaReviewState ?? build.betaReviewState
        let reviewStateText = readableBetaReviewState(betaReviewState) ?? strings.betaReviewStatusNotSubmitted

        return (
            TestFlightDistributionSnapshot(
                appID: app.id,
                buildID: build.id,
                version: version,
                buildNumber: buildNumber,
                processingState: build.processingState,
                betaReviewState: betaReviewState,
                betaReviewStateText: reviewStateText,
                internalGroups: internalGroups,
                externalGroups: externalGroups
            ),
            build,
            client
        )
    }

    private func testFlightDistributionErrorMessage(_ error: Error) -> String {
        switch error {
        case TestFlightDistributionError.missingProjectFields:
            return strings.bundleVersionBuildRequiredBeforeRefreshingDistribution
        case let TestFlightDistributionError.appNotFound(bundleID):
            return strings.appStoreConnectAppNotFound(bundleID)
        case let TestFlightDistributionError.buildNotFound(version, buildNumber):
            return strings.uploadedBuildNotFound(version: version, buildNumber: buildNumber)
        default:
            return strings.refreshTestFlightDistributionFailed(error)
        }
    }

    private func loadAppStoreReviewSnapshot(
        createIfMissing: Bool
    ) async throws -> (snapshot: AppStoreReviewSnapshot, client: AppStoreConnectClientProtocol) {
        guard let project = selectedProject,
              let bundleID = project.bundleID, !bundleID.isEmpty,
              let versionString = project.version, !versionString.isEmpty else {
            throw AppStoreReviewError.missingProjectFields
        }
        guard let account = accountProfile else {
            throw AppStoreReviewError.missingProjectFields
        }

        let client = appStoreConnectClient(for: account)
        guard let app = try await client.fetchApp(bundleID: bundleID) else {
            throw AppStoreReviewError.appNotFound(bundleID)
        }

        let versions = try await client.fetchAppStoreVersions(appID: app.id)
        let version: ASCAppStoreVersion
        if let existing = versions.first(where: { $0.versionString == versionString }) {
            version = existing
        } else if createIfMissing {
            version = try await client.createAppStoreVersion(appID: app.id, versionString: versionString, releaseType: "MANUAL")
        } else {
            throw AppStoreReviewError.versionNotFound(versionString)
        }

        let boundBuildID = try await client.fetchAppStoreVersionBuildID(appStoreVersionID: version.id)
        let builds = try await client.fetchBuilds(appID: app.id, appVersion: version.versionString, buildNumber: nil)
        let selectedBuildID = preferredAppStoreReviewBuildID(
            project: project,
            versionString: version.versionString,
            builds: builds,
            boundBuildID: boundBuildID
        )
        let reviewDetail = try await client.fetchAppStoreReviewDetail(appStoreVersionID: version.id)
        let localizations = try await client.fetchAppStoreVersionLocalizations(appStoreVersionID: version.id)
            .sorted { $0.locale < $1.locale }
        let screenshotSets = try await loadAppStoreReviewScreenshotSets(
            localizations: localizations,
            client: client
        )
        let activeSubmission = try await client.fetchActiveReviewSubmission(appID: app.id)

        let snapshot = AppStoreReviewSnapshot(
            appID: app.id,
            appStoreVersionID: version.id,
            versionString: version.versionString,
            versionState: version.state,
            releaseType: version.releaseType,
            selectedBuildID: selectedBuildID,
            boundBuildID: boundBuildID,
            builds: builds.map { build in
                AppStoreReviewBuildOption(
                    id: build.id,
                    buildNumber: build.version,
                    processingState: build.processingState,
                    isBound: build.id == boundBuildID
                )
            },
            reviewDetail: reviewDetail,
            localizations: localizations,
            screenshotSets: screenshotSets,
            reviewSubmissionState: activeSubmission?.state,
            reviewSubmissionID: activeSubmission?.id
        )
        return (snapshot, client)
    }

    private func loadAppStoreReviewScreenshotSets(
        localizations: [ASCAppStoreVersionLocalization],
        client: AppStoreConnectClientProtocol
    ) async throws -> [AppStoreReviewScreenshotSet] {
        var allSets: [AppStoreReviewScreenshotSet] = []
        for localization in localizations {
            let sets = try await client.fetchAppScreenshotSets(appStoreVersionLocalizationID: localization.id)
                .sorted { $0.screenshotDisplayType < $1.screenshotDisplayType }
            for set in sets {
                let screenshots = try await client.fetchAppScreenshots(appScreenshotSetID: set.id)
                allSets.append(
                    AppStoreReviewScreenshotSet(
                        id: set.id,
                        localizationID: localization.id,
                        locale: localization.locale,
                        screenshotDisplayType: set.screenshotDisplayType,
                        screenshots: screenshots
                    )
                )
            }
        }
        return allSets
    }

    private func preferredAppStoreReviewBuildID(
        project: ProjectProfile,
        versionString: String,
        builds: [ASCBuild],
        boundBuildID: String?
    ) -> String? {
        if let currentSnapshot = currentAppStoreReviewSnapshot,
           let selectedBuildID = currentSnapshot.selectedBuildID,
           builds.contains(where: { $0.id == selectedBuildID }) {
            return selectedBuildID
        }
        if let lastUpload = project.lastUpload,
           lastUpload.succeeded,
           lastUpload.version == versionString,
           let build = builds.first(where: { $0.version == lastUpload.buildNumber }) {
            return build.id
        }
        if let buildNumber = project.buildNumber,
           let build = builds.first(where: { $0.version == buildNumber }) {
            return build.id
        }
        if let boundBuildID, builds.contains(where: { $0.id == boundBuildID }) {
            return boundBuildID
        }
        return builds.first(where: { $0.processingState == "VALID" })?.id ?? builds.first?.id
    }

    private func appStoreReviewErrorMessage(_ error: Error) -> String {
        switch error {
        case AppStoreReviewError.missingProjectFields:
            return strings.bundleVersionRequiredBeforeAppStoreReview
        case let AppStoreReviewError.appNotFound(bundleID):
            return strings.appStoreConnectAppNotFound(bundleID)
        case let AppStoreReviewError.versionNotFound(version):
            return strings.appStoreVersionNotFound(version)
        case AppStoreReviewError.buildNotSelected:
            return strings.selectBuildBeforeAppStoreReviewAction
        case AppStoreReviewError.versionNotLoaded:
            return strings.loadAppStoreVersionBeforeAction
        case AppStoreReviewError.noActiveSubmissionToWithdraw:
            return strings.noActiveReviewSubmissionToWithdraw
        case AppStoreReviewError.selectedBuildNotBound:
            return strings.bindSelectedBuildBeforeSubmittingAppStoreReview
        default:
            return strings.refreshAppStoreReviewFailed(error)
        }
    }

    private func persistState(message: String? = nil) {
        do {
            try accountStore.save(accountProfiles)
            try store.save(persistedProjects())
        } catch {
            uploadState = .failed(message: "\(message ?? strings.failedToSaveChanges) \(error)")
        }
    }

    private func refreshProjectMutationState() {
        guard let project = selectedProject else {
            projectMutationSummary = []
            return
        }

        let applied = appliedProjectSettingsByID[project.id] ?? AppliedProjectSettings(project: project)
        var summary: [String] = []
        appendMutationSummary(&summary, label: strings.bundleID, old: applied.bundleID, new: project.bundleID)
        appendMutationSummary(&summary, label: strings.version, old: applied.version, new: project.version)
        appendMutationSummary(&summary, label: strings.mutationLabelBuildNumber, old: applied.buildNumber, new: project.buildNumber)
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
            privateKeyStatus = try credentialVault.privateKeyExists(for: accountID) ? .saved : .missing
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
        await run(project: project, account: account, language: .english)
    }

    func run(project: ProjectProfile, account: AppleAccountProfile, language: AppLanguage) async -> [CheckResult] {
        let client = AppStoreConnectClient { [credentialVault, jwtSigner] in
            let privateKey = try credentialVault.privateKey(for: account.id)
            return try jwtSigner.makeJWT(account: account, privateKeyPEM: privateKey)
        }
        let engine = ConfigurationCheckEngine(
            environment: XcodeEnvironmentChecker(commandRunner: commandRunner, language: language),
            appStoreConnect: client,
            language: language
        )
        return await engine.run(project: project, account: account)
    }
}
