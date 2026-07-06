import ProjPostCore
import SwiftUI
import UniformTypeIdentifiers

struct ProjectListView: View {
    @ObservedObject var viewModel: AppViewModel
    @EnvironmentObject private var localizationStore: LocalizationStore
    @State private var showProjectDirectoryImporter = false
    @State private var isAddingProject = false
    @State private var isDeleteMode = false
    @State private var selectedProjectsForDeletion: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var isProjectDropTarget = false

    private var strings: AppStrings {
        AppStrings(language: localizationStore.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isDeleteMode ? strings.selectProjectsTitle : strings.projectsTitle)
                        .font(.title3.weight(.semibold))
                    Text(isDeleteMode ? strings.selectProjectsSubtitle : strings.projectsSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isDeleteMode {
                    Menu {
                        Button(role: .destructive) {
                            enterDeleteMode()
                        } label: {
                            Label(strings.deleteProjects, systemImage: "trash")
                        }
                        .disabled(viewModel.projects.isEmpty || viewModel.isOperationRunning)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(width: 28, height: 28)
                    }
                    .menuStyle(.borderlessButton)
                    .help(strings.more)
                    .disabled(viewModel.projects.isEmpty || viewModel.isOperationRunning)
                }
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.projects) { project in
                        Button {
                            if isDeleteMode {
                                toggleDeletionSelection(for: project.id)
                            } else {
                                viewModel.selectProject(project.id)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if isDeleteMode {
                                    Image(systemName: selectedProjectsForDeletion.contains(project.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedProjectsForDeletion.contains(project.id) ? Color.accentColor : Color.secondary.opacity(0.55))
                                        .frame(width: 24, height: 24)
                                }

                                projectCard(for: project, highlightsDeletionSelection: isDeleteMode)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isOperationRunning)
                    }
                }
            }

            if isDeleteMode {
                deleteActions
            } else {
                addProjectActions
            }
        }
        .padding(16)
        .fileImporter(
            isPresented: $showProjectDirectoryImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            addProject(from: url)
        }
        .alert(strings.deleteSelectedProjectsTitle, isPresented: $showDeleteConfirmation) {
            Button(strings.cancel, role: .cancel) {
                showDeleteConfirmation = false
            }
            Button(strings.delete, role: .destructive) {
                viewModel.deleteProjects(selectedProjectsForDeletion)
                exitDeleteMode()
            }
        } message: {
            Text(strings.deleteSelectedProjectsMessage(count: selectedProjectsForDeletion.count))
        }
        .onDrop(of: [.fileURL], isTargeted: $isProjectDropTarget) { providers in
            handleProjectDrop(providers)
        }
    }

    private func addProject(from url: URL) {
        isAddingProject = true
        Task {
            let canAccess = url.startAccessingSecurityScopedResource()

            do {
                try await viewModel.addProjectFromDirectory(url)
            } catch {
                await MainActor.run {
                    viewModel.uploadState = .failed(message: strings.scanFailed(error))
                }
            }

            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }

            await MainActor.run {
                isAddingProject = false
            }
        }
    }

    private var addProjectActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(strings.addProject, systemImage: "plus.square.on.square")
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack {
                Picker(strings.languageTitle, selection: $localizationStore.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(viewModel.isOperationRunning)

                Spacer()
            }

            HStack {
                Button {
                    showProjectDirectoryImporter = true
                } label: {
                    Label(isAddingProject ? strings.scanning : strings.chooseFolder, systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddingProject || viewModel.isOperationRunning)

                Spacer()
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isProjectDropTarget ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1.5)
        }
        .help(strings.chooseOrDropProjectFolderHelp)
    }

    private var deleteActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(strings.selectedCount(selectedProjectsForDeletion.count), systemImage: "checklist")
                .font(.headline)
            HStack {
                Button(strings.cancel) {
                    exitDeleteMode()
                }
                .disabled(viewModel.isOperationRunning)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(strings.delete, systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedProjectsForDeletion.isEmpty || viewModel.isOperationRunning)

                Spacer()
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func projectCard(for project: ProjectProfile, highlightsDeletionSelection: Bool = false) -> some View {
        let isSelected = highlightsDeletionSelection ? selectedProjectsForDeletion.contains(project.id) : viewModel.selectedProject?.id == project.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(project.projectPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if !highlightsDeletionSelection {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
                }
            }

            HStack {
                Label(project.versionDisplay, systemImage: "number")
                Spacer()
                Text(project.statusLabel(language: localizationStore.language))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBackground(for: project), in: Capsule())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }

    private func enterDeleteMode() {
        isDeleteMode = true
        selectedProjectsForDeletion = []
    }

    private func exitDeleteMode() {
        isDeleteMode = false
        selectedProjectsForDeletion = []
        showDeleteConfirmation = false
    }

    private func toggleDeletionSelection(for projectID: UUID) {
        if selectedProjectsForDeletion.contains(projectID) {
            selectedProjectsForDeletion.remove(projectID)
        } else {
            selectedProjectsForDeletion.insert(projectID)
        }
    }

    private func handleProjectDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isAddingProject && !viewModel.isOperationRunning,
              let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = droppedFileURL(from: item) else { return }
            DispatchQueue.main.async {
                addProject(from: url)
            }
        }
        return true
    }

    private func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let nsURL = item as? NSURL {
            return nsURL as URL
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            if let url = URL(string: string), url.isFileURL {
                return url
            }
            if string.hasPrefix("/") {
                return URL(fileURLWithPath: string)
            }
        }
        return nil
    }

    private func statusBackground(for project: ProjectProfile) -> Color {
        guard let lastUpload = project.lastUpload else {
            return .secondary.opacity(0.12)
        }
        return lastUpload.succeeded ? .green.opacity(0.16) : .orange.opacity(0.16)
    }
}
