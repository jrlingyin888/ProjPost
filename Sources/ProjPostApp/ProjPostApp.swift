import ProjPostCore
import SwiftUI

@main
struct ProjPostApp: App {
    var body: some Scene {
        WindowGroup(ProductBranding.displayName) {
            ContentView()
                .frame(minWidth: 1120, minHeight: 720)
        }
    }
}
