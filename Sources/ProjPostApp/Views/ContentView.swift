import ProjPostCore
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var localizationStore = LocalizationStore()
    @Environment(\.openURL) private var openURL

    private var strings: AppStrings {
        AppStrings(language: localizationStore.language)
    }

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
                viewModel.uploadState = .failed(message: strings.loadSavedProjectsFailed(error))
            }
            await viewModel.checkForUpdatesIfNeeded()
        }
        .alert(strings.updateAvailableTitle, isPresented: updateAlertBinding) {
            Button(strings.later, role: .cancel) {
                viewModel.dismissAvailableUpdate()
            }
            if let release = viewModel.availableUpdate {
                Button(strings.downloadUpdate) {
                    openURL(release.releaseURL)
                    viewModel.dismissAvailableUpdate()
                }
            }
        } message: {
            if let release = viewModel.availableUpdate {
                Text(strings.updateAvailableMessage(currentVersion: ProductBranding.appVersion, latestVersion: release.version))
            }
        }
    }

    private var updateAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.availableUpdate != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissAvailableUpdate()
                }
            }
        )
    }
}
