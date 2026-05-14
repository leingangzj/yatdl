// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import AppKit
import SwiftUI

final class PanelController: NSObject {
    static let width:      CGFloat = 320
    static let dropHeight: CGFloat = 480

    private var panel:        NSPanel?
    private var clickMonitor: Any?
    private var localMonitor: Any?
    private var statusItem:   NSStatusItem?
    private(set) var store:   TodoStore?
    private var action:       PanelAction?

    func setup(statusItem: NSStatusItem, store: TodoStore, action: PanelAction) {
        self.statusItem = statusItem
        self.store      = store
        self.action     = action
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard let store else { return }
        if panel == nil { buildPanel(store: store) }
        reposition(for: store.displayMode)
        startClickMonitor()
    }

    func hide() {
        guard !(store?.isPinned ?? false) else { return }

        if store?.displayMode == .slideFromRight, let panel {
            slideOut(panel)
        } else {
            panel?.orderOut(nil)
            stopMonitors()
        }
    }

    // MARK: – Panel construction

    private func buildPanel(store: TodoStore) {
        guard let action else { return }
        let root = ContentView()
            .environmentObject(store)
            .environmentObject(action)
        let host = NSHostingController(rootView: root)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.dropHeight),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        p.isOpaque          = false
        p.backgroundColor   = .clear
        p.hasShadow         = true
        p.level             = .popUpMenu
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.contentViewController = host
        panel = p

        // When the user clicks inside the panel, activate the app so text
        // fields become first-responder and receive keyboard events.
        // Without this, .nonactivatingPanel silently swallows typed input.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak p] event in
            NSApp.activate(ignoringOtherApps: true)
            p?.makeKey()
            return event
        }
    }

    // MARK: – Positioning & animation

    private func reposition(for mode: DisplayMode) {
        guard let panel else { return }
        switch mode {
        case .dropFromMenubar:
            panel.setContentSize(NSSize(width: Self.width, height: Self.dropHeight))
            positionBelowStatusItem(panel)
            panel.orderFront(nil)
        case .slideFromRight:
            let height = NSScreen.main?.visibleFrame.height ?? 800
            panel.setContentSize(NSSize(width: Self.width, height: height))
            slideIn(panel)
        }
    }

    private func positionBelowStatusItem(_ panel: NSPanel) {
        guard let btn       = statusItem?.button,
              let btnWindow = btn.window else { return }
        let rect = btnWindow.convertToScreen(btn.frame)
        panel.setFrameTopLeftPoint(NSPoint(x: rect.midX - Self.width / 2, y: rect.minY))
    }

    // Slide the panel in from off-screen right. Starts the panel one full
    // width off the screen edge, then animates to the final position.
    private func slideIn(_ panel: NSPanel) {
        guard let f = NSScreen.main?.visibleFrame else { return }
        let onScreen  = NSPoint(x: f.maxX - Self.width, y: f.minY)
        let offScreen = NSPoint(x: f.maxX,              y: f.minY)

        panel.setFrameOrigin(offScreen)
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration        = 0.25
            ctx.timingFunction  = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(onScreen)
        }
    }

    private func slideOut(_ panel: NSPanel) {
        guard let f = NSScreen.main?.visibleFrame else {
            panel.orderOut(nil); stopMonitors(); return
        }
        let offScreen = NSPoint(x: f.maxX, y: panel.frame.origin.y)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration       = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(offScreen)
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.stopMonitors()
        }
    }

    // MARK: – Event monitors

    // Global mouse monitor: dismisses the panel when the user clicks anywhere
    // outside it. Mouse events don't require Input Monitoring permission.
    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) { self.hide() }
        }
    }

    private func stopMonitors() {
        clickMonitor.map { NSEvent.removeMonitor($0) }
        clickMonitor = nil
    }
}
