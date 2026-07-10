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
    @EnvironmentObject private var localizationStore: LocalizationStore
    @State private var showAccountFileImporter = false
    @State private var activeAccountFileImport: AccountFileImport?
    @State private var isEditingSavedAccount = false
    @State private var showAppleAccountGuide = false
    @State private var showAdvancedStoreFields = false

    private var strings: AppStrings {
        AppStrings(language: localizationStore.language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                projectFields
                accountFields
                uploadActions
                appStoreReviewActions
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
        .sheet(isPresented: $showAdvancedStoreFields) {
            if let snapshot = appStoreReviewSnapshot {
                AppStoreAdvancedFieldsSheet(
                    snapshot: snapshot,
                    strings: strings,
                    onSave: saveAppStoreReviewAdvancedDraft
                )
            } else {
                EmptyView()
                    .frame(width: 520, height: 320)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedProject?.name ?? strings.selectAProject)
                    .font(.title2.weight(.semibold))
                Text(viewModel.selectedProject?.projectPath ?? strings.selectProjectPrompt)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            HStack {
                Button {
                    do {
                        try viewModel.loadProjects()
                    } catch {
                        viewModel.uploadState = .failed(message: strings.loadProjectsFailed(error))
                    }
                } label: {
                    Label(strings.load, systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isOperationRunning)

                Button {
                    do {
                        try viewModel.saveProjects()
                    } catch {
                        viewModel.uploadState = .failed(message: strings.saveProjectsFailed(error))
                    }
                } label: {
                    Label(strings.save, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isOperationRunning)
            }
        }
    }

    private var projectFields: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                editableRow(strings.name, text: Binding(
                    get: { viewModel.selectedProject?.name ?? "" },
                    set: viewModel.updateSelectedProjectName
                ))
                editableRow(strings.projectPath, text: Binding(
                    get: { viewModel.selectedProject?.projectPath ?? "" },
                    set: viewModel.updateSelectedProjectPath
                ))
                editableRow(strings.bundleID, text: Binding(
                    get: { viewModel.selectedProject?.bundleID ?? "" },
                    set: viewModel.updateSelectedProjectBundleID
                ))
                editableRow(strings.version, text: Binding(
                    get: { viewModel.selectedProject?.version ?? "" },
                    set: viewModel.updateSelectedProjectVersion
                ))
                editableRow(strings.build, text: Binding(
                    get: { viewModel.selectedProject?.buildNumber ?? "" },
                    set: viewModel.updateSelectedProjectBuildNumber
                ))
                editableRow(strings.teamID, text: Binding(
                    get: { viewModel.selectedProject?.teamID ?? "" },
                    set: viewModel.updateSelectedProjectTeamID
                ))
                editableRow(strings.scheme, text: Binding(
                    get: { viewModel.selectedProject?.scheme ?? "" },
                    set: viewModel.updateSelectedProjectScheme
                ))
                editableRow(strings.configuration, text: Binding(
                    get: { viewModel.selectedProject?.configuration ?? "" },
                    set: viewModel.updateSelectedProjectConfiguration
                ))

                if viewModel.hasUnappliedProjectChanges {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label(strings.projectChangesNotApplied, systemImage: "exclamationmark.triangle.fill")
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
                                viewModel.uploadState = .failed(message: strings.applyProjectChangesFailed(error))
                            }
                        } label: {
                            Label(strings.applyProjectChanges, systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                HStack {
                    Button {
                        guard let path = viewModel.selectedProject?.projectPath, !path.isEmpty else {
                            viewModel.uploadState = .failed(message: strings.enterProjectPathBeforeScanning)
                            return
                        }
                        Task {
                            do {
                                try await viewModel.scanProject(atPath: path)
                            } catch {
                                viewModel.uploadState = .failed(message: strings.scanFailed(error))
                            }
                        }
                    } label: {
                        Label(strings.scanProject, systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        } label: {
            Label(strings.projectWorkbench, systemImage: "shippingbox")
        }
        .disabled(viewModel.isOperationRunning)
    }

    private var accountFields: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Picker(strings.savedAccount, selection: accountSelectionBinding) {
                    Text(strings.none)
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
                            Label(strings.editAccount, systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            viewModel.saveAccountProfile()
                            isEditingSavedAccount = false
                        } label: {
                            Label(strings.saveAccount, systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        isEditingSavedAccount = true
                        presentAccountFileImporter(.metadata)
                    } label: {
                        Label(strings.importMetadata, systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        presentAccountFileImporter(.privateKey)
                    } label: {
                        Label(strings.importP8, systemImage: "key.horizontal")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.accountDraft.isComplete)

                    Spacer()
                    privateKeyStatusBadge
                }
            }
        } label: {
            HStack(spacing: 8) {
                Label(strings.appleAccount, systemImage: "person.crop.square")
                Button {
                    showAppleAccountGuide = true
                } label: {
                    Label(strings.guide, systemImage: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help(strings.appleAccountGuideHelp)
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
                        Label(strings.refreshTFStatus, systemImage: "arrow.clockwise")
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
            Label(strings.testFlightUpload, systemImage: "paperplane")
        }
    }

    private var appStoreReviewActions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        Task {
                            await viewModel.refreshAppStoreReviewStatus()
                        }
                    } label: {
                        Label(strings.refreshStoreStatus, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canQueryAppStoreReviewStatus || viewModel.isOperationRunning)

                    Button {
                        Task {
                            await viewModel.prepareAppStoreReviewVersion()
                        }
                    } label: {
                        appStoreReviewOperationLabel(title: strings.prepareStoreVersion, systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canQueryAppStoreReviewStatus || viewModel.isOperationRunning)

                    Button {
                        Task {
                            await viewModel.bindSelectedAppStoreReviewBuild()
                        }
                    } label: {
                        appStoreReviewOperationLabel(title: strings.bindSelectedBuild, systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canBindSelectedAppStoreBuild)

                    Spacer()

                    Button {
                        Task {
                            await viewModel.submitSelectedAppStoreReview()
                        }
                    } label: {
                        appStoreReviewOperationLabel(title: strings.submitStoreReview, systemImage: "paperplane.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmitAppStoreReview)
                }

                Text(strings.appStoreReviewSafeActionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let appStoreReviewStatusText {
                    Text(appStoreReviewStatusText)
                        .font(.caption)
                        .foregroundStyle(appStoreReviewStatusColor)
                }

                Divider()

                if let snapshot = appStoreReviewSnapshot {
                    appStoreReviewSnapshotView(snapshot)
                } else {
                    placeholderRow(title: strings.appStoreReview, value: strings.appStoreReviewNoVersionLoaded)
                }
            }
        } label: {
            Label(strings.appStoreReview, systemImage: "app.badge")
        }
    }

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch viewModel.testFlightDistributionState {
            case .idle:
                placeholderRow(title: strings.testFlightDistribution, value: strings.refreshTFStatusToLoadTesterGroups)
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(strings.loadingTestFlightGroups)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            case .linking(let snapshot):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(strings.linkingExternalTestFlightGroups)
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
                placeholderRow(title: strings.testFlightDistribution, value: message)
            }
        }
    }

    private func distributionSnapshotView(_ snapshot: TestFlightDistributionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                placeholderRow(
                    title: strings.currentBuild,
                    value: "\(snapshot.version) (\(snapshot.buildNumber)) · \(snapshot.betaReviewStateText)"
                )
                Spacer()
            }

            if !snapshot.internalGroups.isEmpty {
                Text(strings.internalTesting)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(snapshot.internalGroups) { group in
                    distributionGroupRow(group)
                }
            }

            Text(strings.externalTesting)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if snapshot.externalGroups.isEmpty {
                placeholderRow(title: strings.externalGroups, value: strings.noExternalGroups)
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

            if !group.isInternalGroup {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await viewModel.linkExternalGroupForLatestBuild(groupID: group.id)
                        }
                    } label: {
                        Label(strings.linkBuild, systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isOperationRunning || (group.isCurrentBuildAssociated && group.publicLinkEnabled))

                    Toggle(strings.autoAfterApproval, isOn: autoLinkExternalGroupBinding(groupID: group.id))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .disabled(viewModel.isOperationRunning)

                    Spacer()
                }
            }

            if let publicLink = group.publicLink, !publicLink.isEmpty {
                Text(publicLink)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.blue)
            } else if !group.isInternalGroup {
                Text(group.publicLinkEnabled ? strings.publicLinkPendingFromApple : strings.publicLinkNotEnabled)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch group.operationState {
            case .idle:
                EmptyView()
            case .linked:
                Text(strings.linked)
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

    private func autoLinkExternalGroupBinding(groupID: String) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.selectedProject?.autoLinkExternalGroupIDsAfterBetaApproval.contains(groupID) ?? false
            },
            set: { isEnabled in
                viewModel.updateAutoLinkExternalGroup(groupID, isEnabled: isEnabled)
            }
        )
    }

    private func groupStatusText(_ group: TestFlightDistributionGroup) -> String {
        if group.isInternalGroup {
            return strings.internalGroupStatus
        }
        return group.publicLinkEnabled ? strings.linkOn : strings.linkOff
    }

    private func groupStatusColor(_ group: TestFlightDistributionGroup) -> Color {
        if group.isInternalGroup {
            return .secondary
        }
        return group.publicLinkEnabled ? .green : .secondary
    }

    private func appStoreReviewSnapshotView(_ snapshot: AppStoreReviewSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(strings.storeVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(snapshot.versionString)
                            .font(.callout.weight(.semibold))
                        if let versionState = snapshot.versionState {
                            Text(readableAppStoreVersionState(versionState))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(strings.selectedBuild)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker(strings.selectedBuild, selection: appStoreBuildSelectionBinding) {
                        Text(strings.none)
                            .tag(Optional<String>.none)
                        ForEach(snapshot.builds) { build in
                            Text(appStoreBuildOptionText(build))
                                .tag(Optional(build.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(strings.releaseStrategy)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    releaseStrategyBadge(snapshot.releaseType)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(snapshot.boundBuildID == snapshot.selectedBuildID && snapshot.selectedBuildID != nil ? strings.buildBound : strings.buildNotBound)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(snapshot.boundBuildID == snapshot.selectedBuildID && snapshot.selectedBuildID != nil ? .green : .orange)
                    if let selected = snapshot.builds.first(where: { $0.id == snapshot.selectedBuildID }) {
                        Text("Build \(selected.buildNumber)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            appStoreReviewInfoView(snapshot.reviewDetail)
            appStoreLocalizationsView(snapshot.localizations)
        }
    }

    private func appStoreReviewInfoView(_ detail: ASCAppStoreReviewDetail?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(strings.appStoreReviewInfo)
                    .font(.callout.weight(.semibold))
                Spacer()
                Button {
                    showAdvancedStoreFields = true
                } label: {
                    Label(strings.editReviewInfo, systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }

            if let detail {
                let contact = [
                    detail.contactFirstName,
                    detail.contactLastName,
                    detail.contactEmail,
                    detail.contactPhone
                ]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                Text(contact.isEmpty ? "-" : contact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(strings.account): \(detail.demoAccountRequired == true ? (detail.demoAccountName ?? "-") : strings.none) · notes \(detail.notes?.isEmpty == false ? strings.filled : "-")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func appStoreLocalizationsView(_ localizations: [ASCAppStoreVersionLocalization]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(strings.storeLocalizations)
                    .font(.callout.weight(.semibold))
                Text(strings.storeLocalizationsSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAdvancedStoreFields = true
                } label: {
                    Label(strings.manageLanguages, systemImage: "globe")
                }
                .buttonStyle(.bordered)
            }

            if localizations.isEmpty {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(localizations, id: \.id) { localization in
                            HStack(spacing: 6) {
                                Text(localization.locale)
                                    .font(.caption.weight(.semibold))
                                Text(localization.whatsNew?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? strings.filled : strings.needsUpdate)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(localization.whatsNew?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? .green : .orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((localization.whatsNew?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if let firstLocalization = localizations.first {
                    placeholderRow(title: strings.whatsNew, value: firstLocalization.whatsNew ?? "-")
                }

                Button {
                    showAdvancedStoreFields = true
                } label: {
                    Label(strings.advancedStoreFields, systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func releaseStrategyBadge(_ releaseType: String?) -> some View {
        let text: String
        switch releaseType {
        case "AFTER_APPROVAL":
            text = strings.afterApprovalRelease
        case "SCHEDULED":
            text = strings.scheduledRelease
        default:
            text = strings.manualRelease
        }

        return Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
    }

    private func appStoreBuildOptionText(_ build: AppStoreReviewBuildOption) -> String {
        var parts = ["\(build.buildNumber)"]
        if let processingState = build.processingState {
            parts.append(processingState)
        }
        if build.isBound {
            parts.append(strings.buildBound)
        }
        return parts.joined(separator: " · ")
    }

    private func readableAppStoreVersionState(_ state: String) -> String {
        state
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    @ViewBuilder
    private var uploadButtonLabel: some View {
        if viewModel.isUploadInProgress {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(strings.uploading)
            }
        } else {
            Label(strings.uploadToTestFlight, systemImage: "icloud.and.arrow.up")
        }
    }

    @ViewBuilder
    private var betaReviewButtonLabel: some View {
        if case .running = viewModel.betaReviewState {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(strings.working)
            }
        } else {
            Label(strings.submitToBetaReview, systemImage: "paperplane.circle")
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
            editableRow(strings.account, text: Binding(
                get: { viewModel.accountDraft.displayName },
                set: { updateAccount(displayName: $0) }
            ))
            editableRow(strings.keyID, text: Binding(
                get: { viewModel.accountDraft.keyID },
                set: { updateAccount(keyID: $0) }
            ))
            editableRow(strings.issuerID, text: Binding(
                get: { viewModel.accountDraft.issuerID },
                set: { updateAccount(issuerID: $0) }
            ))
            editableRow(strings.teamID, text: Binding(
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
                Label(strings.currentAccount, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text(profile.displayName)
                    .font(.headline)
            }

            HStack(alignment: .top, spacing: 18) {
                summaryValue(strings.keyID, maskedIdentifier(profile.keyID))
                summaryValue(strings.issuerID, maskedIdentifier(profile.issuerID))
                summaryValue(strings.teamID, profile.teamID.map(maskedIdentifier) ?? "-")
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
            viewModel.uploadState = .failed(message: strings.metadataImportFailed(error))
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
            viewModel.uploadState = .failed(message: strings.privateKeyImportFailed(error))
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
            title = strings.keyMissing
            systemImage = "exclamationmark.circle"
            color = .orange
        case .saved:
            title = strings.keySaved
            systemImage = "checkmark.circle.fill"
            color = .green
        case .failed:
            title = strings.keyFailed
            systemImage = "xmark.octagon.fill"
            color = .red
        }

        return Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
    }

    private var statusText: String {
        if viewModel.hasUnappliedProjectChanges {
            return strings.applyProjectChangesBeforeChecksOrUploading
        }
        return strings.configurationChecksRunAutomatically
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
            return strings.updatingTestFlightStatus
        case .succeeded(let message):
            return message
        case .failed(let message):
            return message
        }
    }

    private var betaReviewStatusColor: Color {
        if let betaReviewStatusText {
            if betaReviewStatusText.localizedCaseInsensitiveContains("Approved") ||
                betaReviewStatusText.contains("已通过") {
                return .green
            }
            if betaReviewStatusText.localizedCaseInsensitiveContains("Rejected") ||
                betaReviewStatusText.contains("已拒绝") {
                return .red
            }
            if betaReviewStatusText.localizedCaseInsensitiveContains("Waiting for Review") ||
                betaReviewStatusText.localizedCaseInsensitiveContains("In Review") ||
                betaReviewStatusText.localizedCaseInsensitiveContains("Submitted") ||
                betaReviewStatusText.localizedCaseInsensitiveContains("Updating") ||
                betaReviewStatusText.contains("等待审核") ||
                betaReviewStatusText.contains("审核中") ||
                betaReviewStatusText.contains("已提交") ||
                betaReviewStatusText.contains("正在更新") {
                return .yellow
            }
        }

        switch viewModel.betaReviewState {
        case .failed:
            return .red
        case .succeeded:
            return .green
        default:
            return .secondary
        }
    }

    private var appStoreReviewSnapshot: AppStoreReviewSnapshot? {
        switch viewModel.appStoreReviewState {
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

    private var appStoreReviewStatusText: String? {
        switch viewModel.appStoreReviewState {
        case .idle:
            return nil
        case .loading, .preparing, .binding, .saving, .submitting:
            return strings.working
        case .loaded:
            return nil
        case .succeeded(let message, _):
            return message
        case .failed(let message, _):
            return message
        }
    }

    private var appStoreReviewStatusColor: Color {
        switch viewModel.appStoreReviewState {
        case .failed:
            return .red
        case .succeeded:
            return .green
        case .loading, .preparing, .binding, .saving, .submitting:
            return .yellow
        default:
            return .secondary
        }
    }

    private var appStoreBuildSelectionBinding: Binding<String?> {
        Binding(
            get: { appStoreReviewSnapshot?.selectedBuildID },
            set: { viewModel.selectAppStoreReviewBuild($0) }
        )
    }

    private var canBindSelectedAppStoreBuild: Bool {
        guard let snapshot = appStoreReviewSnapshot, let selectedBuildID = snapshot.selectedBuildID else {
            return false
        }
        return !viewModel.isOperationRunning && snapshot.boundBuildID != selectedBuildID
    }

    private var canSubmitAppStoreReview: Bool {
        guard let snapshot = appStoreReviewSnapshot, let selectedBuildID = snapshot.selectedBuildID else {
            return false
        }
        return !viewModel.isOperationRunning && snapshot.boundBuildID == selectedBuildID
    }

    @ViewBuilder
    private func appStoreReviewOperationLabel(title: String, systemImage: String) -> some View {
        if isAppStoreReviewOperationRunning {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(title)
            }
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    private var isAppStoreReviewOperationRunning: Bool {
        switch viewModel.appStoreReviewState {
        case .loading, .preparing, .binding, .saving, .submitting:
            return true
        default:
            return false
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

    private func saveAppStoreReviewAdvancedDraft(_ draft: AppStoreReviewAdvancedDraft) async -> String? {
        await viewModel.saveAppStoreReviewAdvancedDraft(draft)
        if case let .failed(message, _) = viewModel.appStoreReviewState {
            return message
        }
        return nil
    }
}

private struct AppStoreAdvancedLocalizationDraft: Equatable {
    var description: String = ""
    var keywords: String = ""
    var marketingURL: String = ""
    var promotionalText: String = ""
    var supportURL: String = ""
    var whatsNew: String = ""

    init() {}

    init(localization: ASCAppStoreVersionLocalization) {
        description = localization.description ?? ""
        keywords = localization.keywords ?? ""
        marketingURL = localization.marketingURL ?? ""
        promotionalText = localization.promotionalText ?? ""
        supportURL = localization.supportURL ?? ""
        whatsNew = localization.whatsNew ?? ""
    }

    var update: ASCAppStoreVersionLocalizationUpdate {
        ASCAppStoreVersionLocalizationUpdate(
            description: nilIfEmpty(description),
            keywords: nilIfEmpty(keywords),
            marketingURL: nilIfEmpty(marketingURL),
            promotionalText: nilIfEmpty(promotionalText),
            supportURL: nilIfEmpty(supportURL),
            whatsNew: nilIfEmpty(whatsNew)
        )
    }
}

private struct AppStoreReviewDetailDraft: Equatable {
    var contactFirstName: String = ""
    var contactLastName: String = ""
    var contactPhone: String = ""
    var contactEmail: String = ""
    var demoAccountName: String = ""
    var demoAccountPassword: String = ""
    var demoAccountRequired: Bool = false
    var notes: String = ""

    init() {}

    init(detail: ASCAppStoreReviewDetail?) {
        contactFirstName = detail?.contactFirstName ?? ""
        contactLastName = detail?.contactLastName ?? ""
        contactPhone = detail?.contactPhone ?? ""
        contactEmail = detail?.contactEmail ?? ""
        demoAccountName = detail?.demoAccountName ?? ""
        demoAccountPassword = detail?.demoAccountPassword ?? ""
        demoAccountRequired = detail?.demoAccountRequired ?? false
        notes = detail?.notes ?? ""
    }

    var update: ASCAppStoreReviewDetailUpdate {
        ASCAppStoreReviewDetailUpdate(
            contactFirstName: nilIfEmpty(contactFirstName),
            contactLastName: nilIfEmpty(contactLastName),
            contactPhone: nilIfEmpty(contactPhone),
            contactEmail: nilIfEmpty(contactEmail),
            demoAccountName: nilIfEmpty(demoAccountName),
            demoAccountPassword: nilIfEmpty(demoAccountPassword),
            demoAccountRequired: demoAccountRequired,
            notes: nilIfEmpty(notes)
        )
    }
}

private func nilIfEmpty(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : value
}

private struct AppStoreAdvancedFieldsSheet: View {
    var snapshot: AppStoreReviewSnapshot
    var strings: AppStrings
    var onSave: (AppStoreReviewAdvancedDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLocalizationID: String?
    @State private var localizationDrafts: [String: AppStoreAdvancedLocalizationDraft]
    @State private var reviewDraft: AppStoreReviewDetailDraft
    @State private var showReviewPassword = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    init(
        snapshot: AppStoreReviewSnapshot,
        strings: AppStrings,
        onSave: @escaping (AppStoreReviewAdvancedDraft) async -> String?
    ) {
        self.snapshot = snapshot
        self.strings = strings
        self.onSave = onSave
        _selectedLocalizationID = State(initialValue: snapshot.localizations.first?.id)
        _localizationDrafts = State(initialValue: Dictionary(
            uniqueKeysWithValues: snapshot.localizations.map { localization in
                (localization.id, AppStoreAdvancedLocalizationDraft(localization: localization))
            }
        ))
        _reviewDraft = State(initialValue: AppStoreReviewDetailDraft(detail: snapshot.reviewDetail))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(strings.advancedStoreFields, systemImage: "slider.horizontal.3")
                    .font(.headline)
                Text(snapshot.versionString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                Spacer()
                Button(strings.cancel) {
                    dismiss()
                }
                .disabled(isSaving)

                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(strings.save)
                        }
                    } else {
                        Label(strings.save, systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                Divider()
            }

            if snapshot.localizations.isEmpty {
                VStack {
                    Spacer()
                    Text("-")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                HStack(spacing: 0) {
                    localizationList
                    Divider()
                    advancedContent
                }
                .disabled(isSaving)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private var localizationList: some View {
        List(selection: $selectedLocalizationID) {
            ForEach(snapshot.localizations, id: \.id) { localization in
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.locale)
                        .font(.callout.weight(.semibold))
                    Text(draft(for: localization.id).whatsNew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? strings.needsUpdate : strings.filled)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(draft(for: localization.id).whatsNew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green)
                }
                .tag(Optional(localization.id))
                .padding(.vertical, 3)
            }
        }
        .listStyle(.sidebar)
        .frame(width: 170)
    }

    private var advancedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let localization = selectedLocalization {
                    HStack {
                        Text(localization.locale)
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text(localization.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    editBlock(
                        strings.whatsNew,
                        text: draftBinding(for: localization.id, \.whatsNew),
                        minHeight: 80
                    )

                    editBlock(
                        strings.appStoreDescription,
                        text: draftBinding(for: localization.id, \.description),
                        minHeight: 120
                    )

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                        editLine(strings.appStoreKeywords, text: draftBinding(for: localization.id, \.keywords))
                        editLine(strings.appStorePromotionalText, text: draftBinding(for: localization.id, \.promotionalText))
                        editLine(strings.appStoreSupportURL, text: draftBinding(for: localization.id, \.supportURL))
                        editLine(strings.appStoreMarketingURL, text: draftBinding(for: localization.id, \.marketingURL))
                    }

                    screenshotSection(for: localization.id)
                    reviewInfoSection
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reviewInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.appStoreReviewInfo)
                .font(.callout.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Toggle(strings.requiresLogin, isOn: $reviewDraft.demoAccountRequired)
                    .toggleStyle(.checkbox)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    editLine(strings.account, text: $reviewDraft.demoAccountName)
                    passwordLine
                }
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            Text(strings.contactInfo)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                editLine(strings.firstName, text: $reviewDraft.contactFirstName)
                editLine(strings.lastName, text: $reviewDraft.contactLastName)
                editLine(strings.phone, text: $reviewDraft.contactPhone)
                editLine(strings.email, text: $reviewDraft.contactEmail)
            }

            editBlock(strings.reviewNotes, text: $reviewDraft.notes, minHeight: 88)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var passwordLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.password)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                if showReviewPassword {
                    TextField(strings.password, text: $reviewDraft.demoAccountPassword)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField(strings.password, text: $reviewDraft.demoAccountPassword)
                        .textFieldStyle(.roundedBorder)
                }
                Button {
                    showReviewPassword.toggle()
                } label: {
                    Image(systemName: showReviewPassword ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(showReviewPassword ? strings.hidePassword : strings.showPassword)
            }
        }
    }

    private var selectedLocalization: ASCAppStoreVersionLocalization? {
        if let selectedLocalizationID,
           let localization = snapshot.localizations.first(where: { $0.id == selectedLocalizationID }) {
            return localization
        }
        return snapshot.localizations.first
    }

    private func draft(for localizationID: String) -> AppStoreAdvancedLocalizationDraft {
        localizationDrafts[localizationID] ?? AppStoreAdvancedLocalizationDraft()
    }

    private func draftBinding(
        for localizationID: String,
        _ keyPath: WritableKeyPath<AppStoreAdvancedLocalizationDraft, String>
    ) -> Binding<String> {
        Binding(
            get: {
                draft(for: localizationID)[keyPath: keyPath]
            },
            set: { newValue in
                var draft = localizationDrafts[localizationID] ?? AppStoreAdvancedLocalizationDraft()
                draft[keyPath: keyPath] = newValue
                localizationDrafts[localizationID] = draft
            }
        )
    }

    private func editBlock(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35))
                )
        }
    }

    private func editLine(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func screenshotSection(for localizationID: String) -> some View {
        let sets = snapshot.screenshotSets.filter { $0.localizationID == localizationID }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(strings.existingScreenshots)
                    .font(.callout.weight(.semibold))
                Spacer()
            }

            if sets.isEmpty {
                Text(strings.noScreenshots)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sets) { set in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(readableScreenshotDisplayType(set.screenshotDisplayType))
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text("\(set.screenshots.count)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], alignment: .leading, spacing: 10) {
                                ForEach(set.screenshots, id: \.id) { screenshot in
                                    screenshotItem(screenshot)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func screenshotItem(_ screenshot: ASCAppScreenshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            screenshotThumbnail(screenshot)
                .frame(width: 108, height: 142)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            Text(screenshot.fileName ?? screenshot.id)
                .font(.caption2)
                .lineLimit(1)
            if let width = screenshot.width, let height = screenshot.height {
                Text("\(width)x\(height)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 118, alignment: .leading)
    }

    @ViewBuilder
    private func screenshotThumbnail(_ screenshot: ASCAppScreenshot) -> some View {
        if let url = screenshotThumbnailURL(screenshot) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                        .controlSize(.small)
                @unknown default:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private func screenshotThumbnailURL(_ screenshot: ASCAppScreenshot) -> URL? {
        guard var template = screenshot.imageURLTemplate else { return nil }
        template = template
            .replacingOccurrences(of: "{w}", with: "180")
            .replacingOccurrences(of: "{h}", with: "390")
            .replacingOccurrences(of: "{f}", with: "png")
        return URL(string: template)
    }

    private func readableScreenshotDisplayType(_ type: String) -> String {
        switch type {
        case "APP_IPHONE_67":
            return "iPhone 6.7"
        case "APP_IPHONE_65":
            return "iPhone 6.5"
        case "APP_IPHONE_61":
            return "iPhone 6.1"
        case "APP_IPHONE_58":
            return "iPhone 5.8"
        case "APP_IPHONE_55":
            return "iPhone 5.5"
        case "APP_IPAD_PRO_3GEN_129":
            return "iPad Pro 12.9"
        case "APP_IPAD_PRO_3GEN_11":
            return "iPad Pro 11"
        case "APP_IPAD_PRO_129":
            return "iPad Pro 12.9"
        case "APP_WATCH_ULTRA":
            return "Apple Watch Ultra"
        case "APP_WATCH_SERIES_10":
            return "Apple Watch Series 10"
        case "APP_WATCH_SERIES_7":
            return "Apple Watch Series 7"
        default:
            return type
                .replacingOccurrences(of: "APP_", with: "")
                .replacingOccurrences(of: "_", with: " ")
        }
    }

    private func makeAdvancedDraft() -> AppStoreReviewAdvancedDraft {
        AppStoreReviewAdvancedDraft(
            reviewDetailID: snapshot.reviewDetail?.id,
            reviewDetailUpdate: snapshot.reviewDetail == nil ? nil : reviewDraft.update,
            localizationUpdates: snapshot.localizations.map { localization in
                AppStoreReviewLocalizationUpdate(
                    localizationID: localization.id,
                    update: draft(for: localization.id).update
                )
            }
        )
    }

    private func save() async {
        saveErrorMessage = nil
        isSaving = true
        let errorMessage = await onSave(makeAdvancedDraft())
        isSaving = false
        if let errorMessage {
            saveErrorMessage = errorMessage
        } else {
            dismiss()
        }
    }
}
