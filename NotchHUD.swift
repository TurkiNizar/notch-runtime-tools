//
//  NotchHUD.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import SwiftUI
import AppKit

/// Minimal SwiftUI notch strip shown inside a non-activating panel.
struct NotchHUD: View {
    let state: BuildState
    let progress: Double
    var onDismiss: (() -> Void)? = nil
    private let notchGapWidth: CGFloat = 130
    private let topHeight: CGFloat = 32

    init(state: BuildState, progress: Double = 0, onDismiss: (() -> Void)? = nil) {
        self.state = state
        self.progress = progress
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { proxy in
            let gap = min(notchGapWidth, proxy.size.width * 0.6)
            let rowHeight: CGFloat = topHeight - 6

            VStack(spacing: 2) {
                ZStack {
                    HStack(spacing: 0) {
                        Image(systemName: iconName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(iconColor)
                            .frame(height: rowHeight, alignment: .center)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        Spacer()
                        Color.clear
                            .frame(width: gap, height: rowHeight) // reserved space for the camera notch
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        Spacer()
                        if let label = labelText {
                            Text(label)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(iconColor)
                                .lineLimit(1)
                                .frame(height: rowHeight, alignment: .center)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
                .frame(height: topHeight, alignment: .center)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.96))
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 1)
                .clipShape(Capsule())

                ProgressBar(state: state, progress: progress)
                    .frame(width: gap)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss?()
            }
        }
    }

    private var iconName: String {
        switch state {
        case .idle: return "circle"
        case .running, .testing: return "gearshape.fill"
        case .success: return "checkmark"
        case .failed: return "xmark"
        }
    }

    private var labelText: String? {
        switch state {
        case .idle: return nil
        case .running: return "Building…"
        case .testing: return "Testing…"
        case .success: return "Done"
        case .failed: return "Failed"
        }
    }

    private var iconColor: Color {
        switch state {
        case .idle: return .secondary
        case .running: return Color(.systemYellow)
        case .testing: return Color(.systemBlue)
        case .success: return Color(.systemGreen)
        case .failed: return Color(.systemRed)
        }
    }
}

private struct ProgressBar: View {
    let state: BuildState
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                Capsule()
                    .fill(fillGradient)
                    .frame(width: filledWidth(width: width))
                    .animation(.interpolatingSpring(stiffness: 120, damping: 16), value: progress)
                    .shadow(color: Color.white.opacity(0.12), radius: 2, x: 0, y: 0)
            }
        }
        .frame(height: 6)
    }

    private var fillGradient: LinearGradient {
        switch state {
        case .running:
            return LinearGradient(colors: [Color(.systemYellow), Color(.systemGreen)], startPoint: .leading, endPoint: .trailing)
        case .testing:
            return LinearGradient(colors: [Color(.systemBlue), Color(.systemGreen)], startPoint: .leading, endPoint: .trailing)
        case .success:
            return LinearGradient(colors: [Color(.systemGreen)], startPoint: .leading, endPoint: .trailing)
        case .failed:
            return LinearGradient(colors: [Color(.systemRed)], startPoint: .leading, endPoint: .trailing)
        case .idle:
            return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func filledWidth(width: CGFloat) -> CGFloat {
        let clamped = max(0, min(progress, 1))
        switch state {
        case .idle:
            return 0
        case .running, .testing:
            return width * max(clamped, 0.1)
        case .success:
            return width
        case .failed:
            return width
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    VStack(spacing: 12) {
        NotchHUD(state: .running)
            .frame(width: 240, height: 32)
        NotchHUD(state: .success)
            .frame(width: 240, height: 32)
        NotchHUD(state: .failed)
            .frame(width: 240, height: 32)
    }
    .padding()
}
