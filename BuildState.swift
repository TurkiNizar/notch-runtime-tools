//
//  BuildState.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import Foundation

/// Runtime build states used to drive the notch UI.
enum BuildState: Equatable {
    case idle
    case running
    case testing
    case success
    case failed
}
