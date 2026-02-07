//
//  BuildStateMachine.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import Foundation

enum BuildStateEvent {
    case startBuild
    case enterTesting
    case succeed
    case fail
    case reset
}

/// Enforces the allowed lifecycle transitions for the notch HUD.
final class BuildStateMachine {
    private(set) var state: BuildState = .idle {
        didSet {
            guard state != oldValue else { return }
            onStateChange(state)
        }
    }

    var onStateChange: (BuildState) -> Void = { _ in }

    private var successWorkItem: DispatchWorkItem?

    func send(_ event: BuildStateEvent) {
        switch event {
        case .startBuild:
            transitionToRunning()
        case .enterTesting:
            transitionToTesting()
        case .succeed:
            transitionToSuccess()
        case .fail:
            transitionToFailed()
        case .reset:
            transitionToIdle()
        }
    }

    private func transitionToRunning() {
        successWorkItem?.cancel()
        state = .running
    }

    private func transitionToTesting() {
        guard state == .running else { return }
        state = .testing
    }

    private func transitionToSuccess() {
        guard state == .running || state == .testing else { return }
        state = .success
        queueHideAfterSuccess()
    }

    private func transitionToFailed() {
        guard state == .running || state == .testing else { return }
        successWorkItem?.cancel()
        state = .failed
    }

    private func transitionToIdle() {
        successWorkItem?.cancel()
        state = .idle
    }

    private func queueHideAfterSuccess() {
        successWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.state = .idle
        }
        successWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}
