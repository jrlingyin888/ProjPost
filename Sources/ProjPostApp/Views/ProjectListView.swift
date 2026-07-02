import ProjPostCore
import SwiftUI

struct ProjectListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var draftName = ""
    @State private var draftPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Projects")
                    .font(.title3.weight(.semibold))
                Text("Choose a workbench or add a new upload target.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.projects) { project in
                        Button {
                            viewModel.selectProject(project.id)
                        } label: {
                            projectCard(for: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Add Project", systemImage: "plus.square.on.square")
                    .font(.headline)
                TextField("Project name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                TextField("Project path", text: $draftPath)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        viewModel.addProject(named: draftName, projectPath: draftPath)
                        draftName = ""
                        draftPath = ""
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
    }

    private func projectCard(for project: ProjectProfile) -> some View {
        let isSelected = viewModel.selectedProject?.id == project.id

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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
            }

            HStack {
                Label(project.versionDisplay, systemImage: "number")
                Spacer()
                Text(project.statusLabel)
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

    private func statusBackground(for project: ProjectProfile) -> Color {
        guard let lastUpload = project.lastUpload else {
            return .secondary.opacity(0.12)
        }
        return lastUpload.succeeded ? .green.opacity(0.16) : .orange.opacity(0.16)
    }
}
