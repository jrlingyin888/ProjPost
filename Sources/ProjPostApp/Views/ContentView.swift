import ProjPostCore
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationSplitView {
            ProjectListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            ProjectDetailView(viewModel: viewModel)
        }
        .navigationTitle(ProductBranding.displayName)
        .task {
            do {
                try viewModel.loadProjects()
            } catch {
                viewModel.uploadState = .failed(message: "Failed to load saved projects: \(error)")
            }
        }
        .task(id: viewModel.latestBuildStatusTrigger) {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await viewModel.refreshLatestBuildTestFlightStatusIfNeeded()
        }
    }
}
