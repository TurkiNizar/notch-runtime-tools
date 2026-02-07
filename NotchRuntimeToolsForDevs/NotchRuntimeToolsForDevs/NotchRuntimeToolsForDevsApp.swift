import SwiftUI

@main
struct NotchRuntimeToolsForDevsApp: App {
    @StateObject private var coordinator = NotchCoordinator()
    var body: some Scene {
        Settings {
            EmptyView()
                .environmentObject(coordinator)
        }
    }
}
