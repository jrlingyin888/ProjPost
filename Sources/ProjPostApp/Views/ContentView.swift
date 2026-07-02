import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("项目列表")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            Text("选择或添加项目")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
