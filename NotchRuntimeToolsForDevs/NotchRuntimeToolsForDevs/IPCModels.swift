//
//  IPCModels.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import Foundation

/// Baseline payload shared between the CLI wrapper and the notch app.
struct BuildEventPayload: Codable {
    enum EventType: String, Codable {
        case buildStarted
        case phaseChanged
        case progressUpdated
        case buildFailed
        case buildSucceeded
    }

    enum BuildTool: String, Codable {
        case maven
        case gradle
        case npm
        case yarn
        case pnpm
        case unknown
    }

    let event: EventType
    let tool: BuildTool
    let phase: String?
    let timestamp: TimeInterval
    let progress: Double?
}

/// Placeholder transport surface. The concrete implementation will use XPC or a UNIX socket.
protocol BuildEventSink {
    func send(_ payload: BuildEventPayload)
}

/// Temporary no-op sink to allow compilation while IPC is wired up.
final class NoopEventSink: BuildEventSink {
    func send(_ payload: BuildEventPayload) {
        // IPC transport to be implemented in Phase 4.
    }
}
