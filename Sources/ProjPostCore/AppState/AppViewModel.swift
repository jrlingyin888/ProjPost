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

    public func toProfile() -> AppleAccountProfile? {
        guard isComplete else { return nil }
        let trimmedTeamID = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppleAccountProfile(
            id: id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            keyID: keyID.trimmingCharacters(in: .whitespacesAndNewlines),
            issuerID: issuerID.trimmingCharacters(in: .whitespacesAndNewlines),
            teamID: trimmedTeamID.isEmpty ? nil : trimmedTeamID,
            lastVerifiedAt: nil
        )
    }
}

public final class AppViewModel: ObservableObject {
    @Published public private(set) var projects: [ProjectProfile]
    @Published public private(set) var selectedProjectID: UUID?
    @Published public private(set) var accountProfile: AppleAccountProfile?
    @Published public var accountDraft: AppleAccountDraft
    @Published public var checkResults: [CheckResult]
    @Published public var uploadState: UploadJobState
    @Published public var uploadEvents: [UploadEvent]

    private let store: ProjectProfileStoreProtocol
    private let scanner: ProjectScanning
    private let checkEngine: ConfigurationCheckEngineProtocol
    private let uploadRunner: UploadJobRunning

    public init(
        store: ProjectProfileStoreProtocol = ProjectProfileStore.defaultStore(),
        scanner: ProjectScanning? = nil,
        checkEngine: ConfigurationCheckEngineProtocol? = nil,
        uploadRunner: UploadJobRunning? = nil,
        projects: [ProjectProfile] = [],
        accountDraft: AppleAccountDraft = AppleAccountDraft()
    ) {
        let commandRunner = ProcessCommandRunner()
        self.store = store
        self.scanner = scanner ?? ProjectScanner(commandRunner: commandRunner)
        self.checkEngine = checkEngine ?? LiveConfigurationCheckEngine()
        self.uploadRunner = uploadRunner ?? UploadJobRunner(commandRunner: commandRunner, commandBuilder: UploadCommandBuilder())
        self.projects = projects
        self.selectedProjectID = projects.first?.id
        self.accountDraft = accountDraft
        self.accountProfile = accountDraft.toProfile()
        self.checkResults = []
        self.uploadState = .idle
        self.uploadEvents = []
        syncSelectedProjectAccountID()
    }

    public var selectedProject: ProjectProfile? {
        guard let selectedProjectID else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    public var hasYellowChecks: Bool {
        checkResults.contains(where: { $0.severity == .yellow })
    }

    public func loadProjects() throws {
        let loadedProjects = try store.load()
        projects = loadedProjects
        selectedProjectID = loadedProjects.first?.id
        clearRunState()
        syncSelectedProjectAccountID()
    }

    public func saveProjects() throws {
        try store.save(projects)
    }

    public func selectProject(_ id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectID = id
        clearRunState()
        syncSelectedProjectAccountID()
    }

    public func addProject(_ project: ProjectProfile) {
        projects.append(project)
        selectedProjectID = project.id
        clearRunState()
        syncSelectedProjectAccountID()
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
            selectedAccountID: accountProfile?.id,
            lastUpload: nil
        )
        addProject(project)
    }

    public func updateAccountDraft(displayName: String, keyID: String, issuerID: String, teamID: String?) {
        accountDraft = AppleAccountDraft(
            id: accountProfile?.id ?? accountDraft.id ?? selectedProject?.selectedAccountID,
            displayName: displayName,
            keyID: keyID,
            issuerID: issuerID,
            teamID: teamID ?? ""
        )
        accountProfile = accountDraft.toProfile()
        syncSelectedProjectAccountID()
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
        clearRunState()
    }

    public func runChecks() async {
        guard let project = selectedProject else {
            uploadState = .failed(message: "Select a project before running checks.")
            checkResults = []
            return
        }
        guard let account = accountProfile else {
            uploadState = .failed(message: "Select or enter an Apple account before running checks.")
            checkResults = []
            return
        }

        uploadState = .running(step: .checkBundleAndApp)
        let results = await checkEngine.run(project: project, account: account)
        checkResults = results
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
            updated.selectedAccountID = accountProfile?.id
            updated.lastUpload = projects[index].lastUpload
            projects[index] = updated
        } else if let index = projects.firstIndex(where: { $0.projectPath == project.projectPath }) {
            var updated = project
            updated.id = projects[index].id
            updated.selectedAccountID = accountProfile?.id
            updated.lastUpload = projects[index].lastUpload
            projects[index] = updated
            selectedProjectID = updated.id
        } else {
            var newProject = project
            newProject.selectedAccountID = accountProfile?.id
            projects.append(newProject)
            selectedProjectID = newProject.id
        }
    }

    private func mutateSelectedProject(_ mutate: (inout ProjectProfile) -> Void) {
        guard let selectedProjectID, let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        mutate(&projects[index])
    }

    private func syncSelectedProjectAccountID() {
        guard let selectedProjectID, let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        projects[index].selectedAccountID = accountProfile?.id
    }

    private func clearRunState() {
        checkResults = []
        uploadEvents = []
        uploadState = .idle
    }

    private func applyLastUploadSummary(success: Bool, message: String) {
        mutateSelectedProject { project in
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
