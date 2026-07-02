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
    }
}
