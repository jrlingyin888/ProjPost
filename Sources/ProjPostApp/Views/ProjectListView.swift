import ProjPostCore
import SwiftUI

struct ProjectListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var draftName = ""
    @State private var draftPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            List(selection: selectionBinding) {
                ForEach(viewModel.projects) { project in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        Text(project.projectPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(project.versionDisplay)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(project.id)
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 12) {
                Label("Add Project", systemImage: "plus.square.on.square")
                    .font(.headline)
                TextField("Project name", text: $draftName)
                TextField("Project path", text: $draftPath)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        viewModel.addProject(named: draftName, projectPath: draftPath)
                        draftName = ""
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

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedProject?.id },
            set: { newValue in
                guard let newValue else { return }
                viewModel.selectProject(newValue)
            }
        )
    }
}
