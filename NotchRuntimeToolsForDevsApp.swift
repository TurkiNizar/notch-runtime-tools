//
//  NotchRuntimeToolsForDevsApp.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import SwiftUI

@main
struct NotchRuntimeToolsForDevsApp: App {
    @StateObject private var coordinator = NotchCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
