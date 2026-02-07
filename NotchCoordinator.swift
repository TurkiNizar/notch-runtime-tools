//
//  NotchCoordinator.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import Foundation
import Combine

@MainActor
/// Bridges app state updates to the notch window.
final class NotchCoordinator: ObservableObject {
    private var notchWindow: NotchWindowController?
    private let stateMachine = BuildStateMachine()
    private let eventListener = BuildEventListener()
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    @Published private(set) var state: BuildState = .idle
    @Published private(set) var progress: Double = 0
    private var lastStartTimestamp: TimeInterval?

    init() {
        stateMachine.onStateChange = { [weak self] newState in
            DispatchQueue.main.async {
                guard let self else { return }
                self.state = newState
                self.ensureWindow()?.update(state: newState, progress: self.progress)
            }
        }
        startListeningForEvents()
    }

    func send(_ event: BuildStateEvent) {
        stateMachine.send(event)
    }

    private func ensureWindow() -> NotchWindowController? {
        guard notchWindow == nil else { return notchWindow }
        guard !isPreview else { return nil }
        let window = NotchWindowController()
        window.update(state: state, progress: progress)
        notchWindow = window
        return window
    }

    private func startListeningForEvents() {
        guard !isPreview else { return }
        NSLog("NotchCoordinator: starting BuildEventListener")
        eventListener.onPayload = { [weak self] payload in
            self?.handle(payload: payload)
        }
        eventListener.start()
    }

    private func handle(payload: BuildEventPayload) {
        switch payload.event {
        case .buildStarted:
            lastStartTimestamp = payload.timestamp
            progress = 0.05
            stateMachine.send(.startBuild)
        case .phaseChanged:
            if isTestingPhase(payload.phase) {
                progress = max(progress, 0.6)
                stateMachine.send(.enterTesting)
            } else {
                progress = max(progress, 0.2)
                stateMachine.send(.startBuild)
            }
        case .buildFailed:
            progress = max(progress, 1.0)
            stateMachine.send(.fail)
        case .buildSucceeded:
            progress = 1.0
            stateMachine.send(.succeed)
        case .progressUpdated:
            if let p = payload.progress {
                progress = max(progress, p)
            }
        }
        ensureWindow()?.update(state: state, progress: progress)
    }

    private func isTestingPhase(_ phase: String?) -> Bool {
        guard let phase = phase?.lowercased() else { return false }
        return phase.contains("test") || phase.contains("verify") || phase.contains("surefire")
    }

    func dismiss() {
        progress = 0
        stateMachine.send(.reset)
        ensureWindow()?.update(state: .idle, progress: progress)
    }
}
