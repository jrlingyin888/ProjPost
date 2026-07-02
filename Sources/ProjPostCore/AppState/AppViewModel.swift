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

extension ProjectProfileStore: ProjectProfileStoreProtocol {}
extension ProjectScanner: ProjectScanning {}
extension ConfigurationCheckEngine: ConfigurationCheckEngineProtocol {}
extension UploadJobRunner: UploadJobRunning {}

public enum PrivateKeyStatus: Equatable {
    case missing
    case saved
    case failed
}

public enum AppViewModelError: Error, Equatable {
    case incompleteAppleAccount
    case invalidPrivateKeyPEM
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
    @Published public private(set) var privateKeyStatus: PrivateKeyStatus

    private let store: ProjectProfileStoreProtocol
    private let accountStore: AppleAccountProfileStoreProtocol
    private let credentialVault: CredentialVault
    private let scanner: ProjectScanning
    private let checkEngine: ConfigurationCheckEngineProtocol
    private let uploadRunner: UploadJobRunning
    private var lastCheckContext: CheckContext?

    public init(
        store: ProjectProfileStoreProtocol = ProjectProfileStore.defaultStore(),
        accountStore: AppleAccountProfileStoreProtocol = AppleAccountProfileStore.defaultStore(),
        credentialVault: CredentialVault = KeychainCredentialVault(),
        scanner: ProjectScanning? = nil,
        checkEngine: ConfigurationCheckEngineProtocol? = nil,
        uploadRunner: UploadJobRunning? = nil,
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
        self.projects = projects
        self.selectedProjectID = projects.first?.id
        self.accountProfiles = accountProfiles
        self.accountDraft = accountDraft
        self.accountProfile = accountDraft.toProfile()
        self.checkResults = []
        self.uploadState = .idle
        self.uploadEvents = []
        self.privateKeyStatus = .missing
        self.lastCheckContext = nil

        if selectedProject?.selectedAccountID != nil {
            hydrateAccountStateFromSelectedProject()
        } else {
            refreshPrivateKeyStatus()
        }
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

    public func loadProjects() throws {
        let loadedProjects = try store.load()
        let loadedAccounts = try accountStore.load()
        let previousSelection = selectedProjectID
        projects = loadedProjects
        accountProfiles = loadedAccounts
        if let previousSelection, loadedProjects.contains(where: { $0.id == previousSelection }) {
            selectedProjectID = previousSelection
        } else {
            selectedProjectID = loadedProjects.first?.id
        }
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
    }

    public func saveProjects() throws {
        try accountStore.save(accountProfiles)
        try store.save(projects)
    }

    public func selectProject(_ id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectID = id
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
    }

    public func addProject(_ project: ProjectProfile) {
        projects.append(project)
        selectedProjectID = project.id
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
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

    public func updateAccountDraft(displayName: String, keyID: String, issuerID: String, teamID: String?) {
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
        mutateSelectedProject { $0.selectedAccountID = accountID }

        guard let accountID, let storedProfile = accountProfiles.first(where: { $0.id == accountID }) else {
            accountDraft = AppleAccountDraft()
            accountProfile = nil
            invalidateChecks()
            refreshPrivateKeyStatus()
            return
        }

        accountDraft = AppleAccountDraft(profile: storedProfile)
        accountProfile = storedProfile
        invalidateChecks()
        refreshPrivateKeyStatus()
    }

    public func saveAccountProfile() {
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
        mutateSelectedProject { $0.selectedAccountID = profile.id }
        refreshPrivateKeyStatus()
    }

    public func importPrivateKey(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let pem = String(decoding: data, as: UTF8.self)
        try importPrivateKeyPEM(pem)
    }

    public func importPrivateKeyPEM(_ privateKeyPEM: String) throws {
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
        mutateSelectedProject { $0.name = value }
    }

    public func updateSelectedProjectPath(_ value: String) {
        mutateSelectedProject { $0.projectPath = value }
    }

    public func updateSelectedProjectBundleID(_ value: String) {
        mutateSelectedProject { $0.bundleID = Self.normalized(value) }
    }

    public func updateSelectedProjectVersion(_ value: String) {
        mutateSelectedProject { $0.version = Self.normalized(value) }
    }

    public func updateSelectedProjectBuildNumber(_ value: String) {
        mutateSelectedProject { $0.buildNumber = Self.normalized(value) }
    }

    public func updateSelectedProjectTeamID(_ value: String) {
        mutateSelectedProject { $0.teamID = Self.normalized(value) }
    }

    public func updateSelectedProjectScheme(_ value: String) {
        mutateSelectedProject { $0.scheme = Self.normalized(value) }
    }

    public func updateSelectedProjectConfiguration(_ value: String) {
        mutateSelectedProject { $0.configuration = value.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    public func scanProject(atPath path: String) async throws {
        let scanResult = try await scanner.scan(projectPath: URL(fileURLWithPath: path))
        let scannedProject = scanResult.toProjectProfile(nameOverride: selectedProject?.name)
        upsertProject(scannedProject)
        invalidateChecks()
        hydrateAccountStateFromSelectedProject()
    }

    public func runChecks() async {
        guard let project = selectedProject else {
            lastCheckContext = nil
            uploadState = .failed(message: "Select a project before running checks.")
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

    public func startUpload(confirmedYellowIssues: Bool = false) async {
        guard let project = selectedProject else {
            uploadState = .failed(message: "Select a project before starting upload.")
            return
        }
        guard let account = accountProfile else {
            uploadState = .failed(message: "Select or enter an Apple account before uploading.")
            return
        }
        guard checksAreCurrent else {
            uploadState = .failed(message: "Run configuration checks for the current project and Apple account before uploading.")
            return
        }
        if checkResults.blocksUpload {
            uploadState = .failed(message: "Upload blocked by configuration issues. Resolve red checks before uploading.")
            return
        }
        if hasYellowChecks && !confirmedYellowIssues {
            uploadState = .failed(message: "Upload requires confirmation for yellow configuration issues.")
            return
        }

        uploadState = .running(step: .archive)
        uploadEvents = []

        do {
            let events = try await uploadRunner.runLocalUpload(project: project, account: account)
            uploadEvents = events
            uploadState = .succeeded(message: "Upload finished successfully.")
            applyLastUploadSummary(success: true, message: events.last?.message ?? "Upload finished successfully.")
        } catch {
            uploadState = .failed(message: "Upload failed: \(error)")
            applyLastUploadSummary(success: false, message: "Upload failed: \(error)")
        }
    }

    private func upsertProject(_ project: ProjectProfile) {
        if let selectedProjectID, let index = projects.firstIndex(where: { $0.id == selectedProjectID }) {
            var updated = project
            updated.id = selectedProjectID
            updated.name = projects[index].name.isEmpty ? project.name : projects[index].name
            updated.selectedAccountID = projects[index].selectedAccountID
            updated.lastUpload = projects[index].lastUpload
            projects[index] = updated
        } else if let index = projects.firstIndex(where: { $0.projectPath == project.projectPath }) {
            var updated = project
            updated.id = projects[index].id
            updated.selectedAccountID = projects[index].selectedAccountID
            updated.lastUpload = projects[index].lastUpload
            projects[index] = updated
            selectedProjectID = updated.id
        } else {
            var newProject = project
            newProject.selectedAccountID = nil
            projects.append(newProject)
            selectedProjectID = newProject.id
        }
    }

    private func mutateSelectedProject(invalidateChecks: Bool = true, _ mutate: (inout ProjectProfile) -> Void) {
        guard let selectedProjectID, let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        mutate(&projects[index])
        if invalidateChecks {
            self.invalidateChecks()
        }
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
    let selectedAccountID: UUID?

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
        self.selectedAccountID = project.selectedAccountID
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
