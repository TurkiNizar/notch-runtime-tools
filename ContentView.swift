//
//  ContentView.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: NotchCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notch Build HUD")
                .font(.title2.weight(.bold))

            Text("Use the controls below to simulate build states. The notch strip appears only when a build is active.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                stateButton(.running, title: "Running")
                stateButton(.testing, title: "Testing")
                stateButton(.success, title: "Success")
                stateButton(.failed, title: "Failed")
                stateButton(.idle, title: "Hide")
            }

            Divider()

            HStack {
                Text("Current state:")
                Text(displayName(for: coordinator.state))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 200)
    }

    private func stateButton(_ state: BuildState, title: String) -> some View {
        Button(title) {
            switch state {
            case .running:
                coordinator.send(.startBuild)
            case .testing:
                coordinator.send(.enterTesting)
            case .success:
                coordinator.send(.succeed)
            case .failed:
                coordinator.send(.fail)
            case .idle:
                coordinator.send(.reset)
            }
        }
    }

    private func displayName(for state: BuildState) -> String {
        switch state {
        case .idle: return "Idle"
        case .running: return "Running"
        case .testing: return "Testing"
        case .success: return "Success"
        case .failed: return "Failed"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotchCoordinator())
}
