import ProjPostCore
import SwiftUI
import UniformTypeIdentifiers

private enum AccountFileImport {
    case metadata
    case privateKey

    var allowedContentTypes: [UTType] {
        switch self {
        case .metadata:
            return [.plainText, .rtf, UTType(filenameExtension: "txt") ?? .plainText]
        case .privateKey:
            return [UTType(filenameExtension: "p8") ?? .data, .data]
        }
    }
}

struct ProjectDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showAccountFileImporter = false
    @State private var activeAccountFileImport: AccountFileImport?
    @State private var isEditingSavedAccount = false
    @State private var showAppleAccountGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                projectFields
                accountFields
                uploadActions
                UploadProgressView(state: viewModel.uploadState, events: viewModel.uploadEvents)
            }
            .padding(20)
        }
        .fileImporter(
            isPresented: $showAccountFileImporter,
            allowedContentTypes: activeAccountFileImport?.allowedContentTypes ?? [.data],
            allowsMultipleSelection: false
        ) { result in
            defer { activeAccountFileImport = nil }
            guard case let .success(urls) = result, let url = urls.first else { return }
            switch activeAccountFileImport {
            case .metadata:
                importAccountMetadata(from: url)
            case .privateKey:
                importPrivateKey(from: url)
            case nil:
                break
            }
        }
        .sheet(isPresented: $showAppleAccountGuide) {
            AppleAccountGuideView()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedProject?.name ?? "Select a project")
                    .font(.title2.weight(.semibold))
                Text(viewModel.selectedProject?.projectPath ?? "Choose a project from the sidebar or add one.")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            HStack {
                Button {
                    do {
                        try viewModel.loadProjects()
                    } catch {
                        viewModel.uploadState = .failed(message: "Failed to load projects: \(error)")
                    }
                } label: {
                    Label("Load", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isOperationRunning)

                Button {
                    do {
                        try viewModel.saveProjects()
                    } catch {
                        viewModel.uploadState = .failed(message: "Failed to save projects: \(error)")
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isOperationRunning)
            }
        }
    }

    private var projectFields: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                editableRow("Name", text: Binding(
                    get: { viewModel.selectedProject?.name ?? "" },
                    set: viewModel.updateSelectedProjectName
                ))
                editableRow("Project Path", text: Binding(
                    get: { viewModel.selectedProject?.projectPath ?? "" },
                    set: viewModel.updateSelectedProjectPath
                ))
                editableRow("Bundle ID", text: Binding(
                    get: { viewModel.selectedProject?.bundleID ?? "" },
                    set: viewModel.updateSelectedProjectBundleID
                ))
                editableRow("Version", text: Binding(
                    get: { viewModel.selectedProject?.version ?? "" },
                    set: viewModel.updateSelectedProjectVersion
                ))
                editableRow("Build", text: Binding(
                    get: { viewModel.selectedProject?.buildNumber ?? "" },
                    set: viewModel.updateSelectedProjectBuildNumber
                ))
                editableRow("Team ID", text: Binding(
                    get: { viewModel.selectedProject?.teamID ?? "" },
                    set: viewModel.updateSelectedProjectTeamID
                ))
                editableRow("Scheme", text: Binding(
                    get: { viewModel.selectedProject?.scheme ?? "" },
                    set: viewModel.updateSelectedProjectScheme
                ))
                editableRow("Configuration", text: Binding(
                    get: { viewModel.selectedProject?.configuration ?? "" },
                    set: viewModel.updateSelectedProjectConfiguration
                ))

                if viewModel.hasUnappliedProjectChanges {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Project changes are not applied to disk yet.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        ForEach(viewModel.projectMutationSummary, id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            do {
                                try viewModel.applyProjectChanges()
                            } catch {
                                viewModel.uploadState = .failed(message: "Apply project changes failed: \(error)")
                            }
                        } label: {
                            Label("Apply Project Changes", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                HStack {
                    Button {
                        guard let path = viewModel.selectedProject?.projectPath, !path.isEmpty else {
                            viewModel.uploadState = .failed(message: "Enter a project path before scanning.")
                            return
                        }
                        Task {
                            do {
                                try await viewModel.scanProject(atPath: path)
                            } catch {
                                viewModel.uploadState = .failed(message: "Scan failed: \(error)")
                            }
                        }
                    } label: {
                        Label("Scan Project", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        } label: {
            Label("Project Workbench", systemImage: "shippingbox")
        }
        .disabled(viewModel.isOperationRunning)
    }

    private var accountFields: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Saved Account", selection: accountSelectionBinding) {
                    Text("None")
                        .tag(Optional<UUID>.none)
                    ForEach(viewModel.accountProfiles) { profile in
                        Text(profile.displayName)
                            .tag(Optional(profile.id))
                    }
                }

                if let savedAccount = savedSelectedAccount, !isEditingSavedAccount {
                    savedAccountSummary(savedAccount)
                } else {
                    accountEditableFields
                }

                HStack(spacing: 12) {
                    if savedSelectedAccount != nil && !isEditingSavedAccount {
                        Button {
                            isEditingSavedAccount = true
                        } label: {
                            Label("Edit Account", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            viewModel.saveAccountProfile()
                            isEditingSavedAccount = false
                        } label: {
                            Label("Save Account", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        isEditingSavedAccount = true
                        presentAccountFileImporter(.metadata)
                    } label: {
                        Label("Import Metadata", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        presentAccountFileImporter(.privateKey)
                    } label: {
                        Label("Import .p8", systemImage: "key.horizontal")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.accountDraft.isComplete)

                    Spacer()
                    privateKeyStatusBadge
                }
            }
        } label: {
            HStack(spacing: 8) {
                Label("Apple Account", systemImage: "person.crop.square")
                Button {
                    showAppleAccountGuide = true
                } label: {
                    Label("Guide", systemImage: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("How to find .p8, Key ID, Issuer ID, and Team ID")
            }
        }
        .disabled(viewModel.isOperationRunning)
    }

    private var uploadActions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        Task {
                            await viewModel.startUpload()
                        }
                    } label: {
                        uploadButtonLabel
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.hasUnappliedProjectChanges || viewModel.isOperationRunning)

                    if viewModel.canQueryLatestBuildTestFlightStatus {
                        Button {
                            Task {
                                await viewModel.refreshLatestBuildTestFlightStatus()
                            }
                        } label: {
                            Label("Refresh TF Status", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning)

                        Button {
                            Task {
                                await viewModel.submitLatestBuildForBetaReview()
                            }
                        } label: {
                            betaReviewButtonLabel
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.canSubmitLatestBuildForBetaReview)
                    }

                    Spacer()
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                if let betaReviewStatusText {
                    Text(betaReviewStatusText)
                        .font(.caption)
                        .foregroundStyle(betaReviewStatusColor)
                }

                Divider()

                distributionSection
            }
        } label: {
            Label("TestFlight Upload", systemImage: "paperplane")
        }
    }

    private var autoLinkExternalGroupsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedProject?.autoLinkExternalGroupsAfterBetaApproval ?? true },
            set: { viewModel.updateAutoLinkExternalGroupsAfterBetaApproval($0) }
        )
    }

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

    private func distributionSnapshotView(_ snapshot: TestFlightDistributionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
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
                Text(groupStatusText(group))
                    .font(.caption)
                    .foregroundStyle(groupStatusColor(group))
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

    private func groupStatusText(_ group: TestFlightDistributionGroup) -> String {
        if group.isInternalGroup {
            return "Internal"
        }
        return group.publicLinkEnabled ? "Link On" : "Link Off"
    }

    private func groupStatusColor(_ group: TestFlightDistributionGroup) -> Color {
        if group.isInternalGroup {
            return .secondary
        }
        return group.publicLinkEnabled ? .green : .secondary
    }

    @ViewBuilder
    private var uploadButtonLabel: some View {
        if viewModel.isUploadInProgress {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Uploading...")
            }
        } else {
            Label("Upload to TestFlight", systemImage: "icloud.and.arrow.up")
        }
    }

    @ViewBuilder
    private var betaReviewButtonLabel: some View {
        if case .running = viewModel.betaReviewState {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Working...")
            }
        } else {
            Label("Submit to Beta Review", systemImage: "paperplane.circle")
        }
    }

    private func editableRow(_ title: String, text: Binding<String>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .frame(width: 110, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var accountEditableFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            editableRow("Account", text: Binding(
                get: { viewModel.accountDraft.displayName },
                set: { updateAccount(displayName: $0) }
            ))
            editableRow("Key ID", text: Binding(
                get: { viewModel.accountDraft.keyID },
                set: { updateAccount(keyID: $0) }
            ))
            editableRow("Issuer ID", text: Binding(
                get: { viewModel.accountDraft.issuerID },
                set: { updateAccount(issuerID: $0) }
            ))
            editableRow("Team ID", text: Binding(
                get: { viewModel.accountDraft.teamID },
                set: { updateAccount(teamID: $0) }
            ))
        }
    }

    private var savedSelectedAccount: AppleAccountProfile? {
        guard let selectedAccountID = viewModel.selectedProject?.selectedAccountID else { return nil }
        return viewModel.accountProfiles.first(where: { $0.id == selectedAccountID })
    }

    private func savedAccountSummary(_ profile: AppleAccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Current Account", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text(profile.displayName)
                    .font(.headline)
            }

            HStack(alignment: .top, spacing: 18) {
                summaryValue("Key ID", maskedIdentifier(profile.keyID))
                summaryValue("Issuer ID", maskedIdentifier(profile.issuerID))
                summaryValue("Team ID", profile.teamID.map(maskedIdentifier) ?? "-")
            }
        }
        .font(.caption)
    }

    private func summaryValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func maskedIdentifier(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return String(repeating: "*", count: max(trimmed.count, 4))
        }
        return "\(trimmed.prefix(4))...\(trimmed.suffix(4))"
    }

    private func updateAccount(displayName: String? = nil, keyID: String? = nil, issuerID: String? = nil, teamID: String? = nil) {
        viewModel.updateAccountDraft(
            displayName: displayName ?? viewModel.accountDraft.displayName,
            keyID: keyID ?? viewModel.accountDraft.keyID,
            issuerID: issuerID ?? viewModel.accountDraft.issuerID,
            teamID: teamID ?? viewModel.accountDraft.teamID
        )
    }

    private func presentAccountFileImporter(_ importType: AccountFileImport) {
        activeAccountFileImport = importType
        showAccountFileImporter = true
    }

    private func importAccountMetadata(from url: URL) {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try viewModel.importAppleAccountMetadata(from: url)
        } catch {
            viewModel.uploadState = .failed(message: "Metadata import failed: \(error)")
        }
    }

    private func importPrivateKey(from url: URL) {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try viewModel.importPrivateKey(from: url)
        } catch {
            if case .failed = viewModel.uploadState {
                return
            }
            viewModel.uploadState = .failed(message: "Private key import failed: \(error)")
        }
    }

    private var accountSelectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedProject?.selectedAccountID },
            set: {
                isEditingSavedAccount = false
                viewModel.selectAccountProfile($0)
            }
        )
    }

    private var privateKeyStatusBadge: some View {
        let title: String
        let systemImage: String
        let color: Color

        switch viewModel.privateKeyStatus {
        case .missing:
            title = "Key Missing"
            systemImage = "exclamationmark.circle"
            color = .orange
        case .saved:
            title = "Key Saved"
            systemImage = "checkmark.circle.fill"
            color = .green
        case .failed:
            title = "Key Failed"
            systemImage = "xmark.octagon.fill"
            color = .red
        }

        return Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
    }

    private var statusText: String {
        if viewModel.hasUnappliedProjectChanges {
            return "Apply project changes before running checks or uploading."
        }
        return "Configuration checks run automatically when upload starts."
    }

    private var statusColor: Color {
        if viewModel.hasUnappliedProjectChanges {
            return .orange
        }
        return .secondary
    }

    private var betaReviewStatusText: String? {
        switch viewModel.betaReviewState {
        case .idle:
            return nil
        case .running:
            return "Updating TestFlight status..."
        case .succeeded(let message):
            return message
        case .failed(let message):
            return message
        }
    }

    private var betaReviewStatusColor: Color {
        switch viewModel.betaReviewState {
        case .failed:
            return .orange
        case .succeeded:
            return .green
        default:
            return .secondary
        }
    }

    private func placeholderRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }
}
