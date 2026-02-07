//
//  NotchWindowController.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import AppKit
import SwiftUI

@MainActor
/// Manages a floating window that hugs the notch area.
final class NotchWindowController: NSWindowController {
    private let windowHeight: CGFloat = 60
    private let windowWidth: CGFloat = 340
    private let collapsedWidth: CGFloat = 160

    private var hostingController: NSHostingController<NotchHUD>?
    private var currentState: BuildState = .idle
    private var currentProgress: Double = 0
    private var isVisible = false
    private var autoHideTimer: Timer?

    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.backgroundColor = .clear
        super.init(window: panel)

        let hud = NotchHUD(state: currentState, progress: currentProgress, onDismiss: { [weak self] in
            self?.handleDismiss()
        })
        let hosting = NSHostingController(rootView: hud)
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = windowHeight / 2
        hosting.view.layer?.masksToBounds = false
        panel.contentViewController = hosting
        panel.contentView?.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        hostingController = hosting

        setVisible(false)
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Aligns the window under the notch on the main display.
    private func targetFrame() -> NSRect? {
        guard let screen = NSScreen.main else { return nil }
        let margin: CGFloat = 0
        let y = screen.frame.maxY - windowHeight - margin
        let x = screen.frame.midX - (windowWidth / 2)
        return NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }

    private func collapsedFrame(around target: NSRect) -> NSRect {
        return NSRect(
            x: target.midX - (collapsedWidth / 2),
            y: target.origin.y + 6,
            width: collapsedWidth,
            height: target.height
        )
    }

    /// Updates content and visibility for a new build state.
    func update(state: BuildState, progress: Double) {
        currentState = state
        currentProgress = progress

        let nextVisibility = state != .idle
        setVisible(nextVisibility)
        hostingController?.rootView = NotchHUD(state: state, progress: progress, onDismiss: { [weak self] in
            self?.handleDismiss()
        })
        scheduleAutoHideIfNeeded()
    }

    private func handleDismiss() {
        currentState = .idle
        currentProgress = 0
        setVisible(false)
        autoHideTimer?.invalidate()
    }

    private func setVisible(_ visible: Bool) {
        guard let panel = window as? NSPanel else { return }
        guard visible != isVisible else { return }
        guard let target = targetFrame() else { return }
        if visible {
            // Start near the notch center with a narrower width, then expand.
            let collapsed = collapsedFrame(around: target)
            panel.setFrame(collapsed, display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                panel.animator().alphaValue = 1
                panel.animator().setFrame(target, display: false)
            }
            isVisible = true
        } else {
            autoHideTimer?.invalidate()
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
                panel.animator().alphaValue = 0
                let collapsed = collapsedFrame(around: target)
                panel.animator().setFrame(collapsed, display: false)
            }, completionHandler: {
                panel.setFrame(target, display: false)
                panel.orderOut(nil)
                panel.alphaValue = 1
            })
            isVisible = false
        }
    }

    private func scheduleAutoHideIfNeeded() {
        autoHideTimer?.invalidate()
        guard currentState == .success else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.handleDismiss()
            }
        }
    }
}
