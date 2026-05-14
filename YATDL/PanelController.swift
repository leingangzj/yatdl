// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import AppKit
import SwiftUI

final class PanelController: NSObject {
    static let width:  CGFloat = 320
    static let height: CGFloat = 480

    private var panel:        NSPanel?
    private var clickMonitor: Any?
    private var statusItem:   NSStatusItem?
    private(set) var store:   TodoStore?

    func setup(statusItem: NSStatusItem, store: TodoStore) {
        self.statusItem = statusItem
        self.store      = store
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard let store else { return }
        if panel == nil { buildPanel(store: store) }
        reposition(for: store.displayMode)
        panel?.orderFront(nil)
        startClickMonitor()
    }

    func hide() {
        guard !(store?.isPinned ?? false) else { return }
        panel?.orderOut(nil)
        stopClickMonitor()
    }

    private func buildPanel(store: TodoStore) {
        let root = ContentView().environmentObject(store)
        let host = NSHostingController(rootView: root)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        // Transparent so the SwiftUI .regularMaterial background composites
        // correctly against whatever's on screen behind the panel.
        p.isOpaque        = false
        p.backgroundColor = .clear
        p.hasShadow       = true
        p.level           = .popUpMenu
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.contentViewController = host
        panel = p
    }

    private func reposition(for mode: DisplayMode) {
        guard let panel else { return }
        switch mode {
        case .dropFromMenubar: positionBelowStatusItem(panel)
        case .slideFromRight:  positionAtRightEdge(panel)
        }
    }

    private func positionBelowStatusItem(_ panel: NSPanel) {
        guard let btn       = statusItem?.button,
              let btnWindow = btn.window else { return }
        let rect = btnWindow.convertToScreen(btn.frame)
        panel.setFrameTopLeftPoint(NSPoint(x: rect.midX - Self.width / 2, y: rect.minY))
    }

    private func positionAtRightEdge(_ panel: NSPanel) {
        guard let f = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: f.maxX - Self.width, y: f.maxY - Self.height))
    }

    // Global mouse event monitor: fires when the user clicks anywhere outside
    // the panel. Mouse events (unlike keyboard) don't need Input Monitoring.
    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) { self.hide() }
        }
    }

    private func stopClickMonitor() {
        clickMonitor.map { NSEvent.removeMonitor($0) }
        clickMonitor = nil
    }
}
