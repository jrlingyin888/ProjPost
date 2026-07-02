import ProjPostCore
import SwiftUI
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showYellowConfirmation = false
    @State private var showPrivateKeyImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                projectFields
                accountFields
                CheckResultsView(results: viewModel.checkResults)
                uploadActions
                UploadProgressView(state: viewModel.uploadState, events: viewModel.uploadEvents)
            }
            .padding(20)
        }
        .alert("Proceed with yellow issues?", isPresented: $showYellowConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Upload") {
                Task {
                    await viewModel.startUpload(confirmedYellowIssues: true)
                }
            }
        } message: {
            Text("Configuration checks returned warnings that need explicit confirmation before upload.")
        }
        .fileImporter(
            isPresented: $showPrivateKeyImporter,
            allowedContentTypes: [UTType(filenameExtension: "p8") ?? .data, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            do {
                try viewModel.importPrivateKey(from: url)
            } catch {
                // AppViewModel already translates failures into non-secret UI state.
            }
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

                HStack(spacing: 12) {
                    Button {
                        viewModel.saveAccountProfile()
                    } label: {
                        Label("Save Account", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showPrivateKeyImporter = true
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
            Label("Apple Account", systemImage: "person.crop.square")
        }
    }

    private var uploadActions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        Task {
                            await viewModel.runChecks()
                        }
                    } label: {
                        Label("Run Checks", systemImage: "checklist")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.hasUnappliedProjectChanges)

                    Button {
                        if viewModel.hasCurrentYellowChecks {
                            showYellowConfirmation = true
                        } else {
                            Task {
                                await viewModel.startUpload()
                            }
                        }
                    } label: {
                        Label("Upload to TestFlight", systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.hasUnappliedProjectChanges)

                    Spacer()
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    placeholderRow(title: "Internal testers", value: "Available after the next successful upload")
                    placeholderRow(title: "Public TestFlight link", value: "Create a public link after Apple finishes processing")
                }
            }
        } label: {
            Label("TestFlight Upload", systemImage: "paperplane")
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

    private func updateAccount(displayName: String? = nil, keyID: String? = nil, issuerID: String? = nil, teamID: String? = nil) {
        viewModel.updateAccountDraft(
            displayName: displayName ?? viewModel.accountDraft.displayName,
            keyID: keyID ?? viewModel.accountDraft.keyID,
            issuerID: issuerID ?? viewModel.accountDraft.issuerID,
            teamID: teamID ?? viewModel.accountDraft.teamID
        )
    }

    private var accountSelectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedProject?.selectedAccountID },
            set: { viewModel.selectAccountProfile($0) }
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
        return viewModel.checksAreCurrent ? "Checks are current for this project and Apple account." : "Run checks again after any project, account, or key change."
    }

    private var statusColor: Color {
        if viewModel.hasUnappliedProjectChanges {
            return .orange
        }
        return viewModel.checksAreCurrent ? .secondary : .orange
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
