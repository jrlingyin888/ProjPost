import ProjPostCore
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var localizationStore = LocalizationStore()

    var body: some View {
        NavigationSplitView {
            ProjectListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            ProjectDetailView(viewModel: viewModel)
        }
        .navigationTitle(ProductBranding.displayName)
        .environmentObject(localizationStore)
        .onAppear {
            viewModel.updateLanguage(localizationStore.language)
        }
        .onReceive(localizationStore.$language) { language in
            viewModel.updateLanguage(language)
        }
        .task {
            do {
                try viewModel.loadProjects()
            } catch {
                viewModel.uploadState = .failed(message: AppStrings(language: localizationStore.language).loadSavedProjectsFailed(error))
            }
        }
    }
}
