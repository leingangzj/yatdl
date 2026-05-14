// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import AppKit
import SwiftUI

// Borderless NSPanel returns canBecomeKey = false by default, which silently
// prevents makeKeyAndOrderFront from working and blocks all text field input.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey:  Bool { true  }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject {
    static let width:      CGFloat = 320
    static let dropHeight: CGFloat = 480

    private var panel:         NSPanel?
    private var clickMonitor:  Any?
    private var localMonitor:  Any?
    private var statusItem:    NSStatusItem?
    private(set) var store:    TodoStore?
    private var settings:      AppSettings?
    private var action:        PanelAction?
    private var previousApp:   NSRunningApplication?

    // Hot-edge state (slide-from-right mode only)
    private var edgeTimer:      Timer?
    private var retractTimer:   Timer?
    private var edgeDwellCount  = 0
    private var hotEdgeShown    = false  // shown via hover, not manual

    func setup(statusItem: NSStatusItem, store: TodoStore, settings: AppSettings, action: PanelAction) {
        self.statusItem = statusItem
        self.store      = store
        self.settings   = settings
        self.action     = action
        startEdgeTimer()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? hide() : show() }

    // MARK: – Manual show/hide

    func show() {
        guard let store else { return }
        previousApp  = NSWorkspace.shared.frontmostApplication
        hotEdgeShown = false
        retractTimer?.invalidate(); retractTimer = nil

        if panel == nil { buildPanel(store: store) }
        reposition(for: store.displayMode)
        NSApp.activate(ignoringOtherApps: true)
        startClickMonitor()
    }

    func hide() {
        guard !(store?.isPinned ?? false) else { return }
        previousApp?.activate()
        previousApp  = nil
        hotEdgeShown = false
        retractTimer?.invalidate(); retractTimer = nil

        if store?.displayMode == .slideFromRight, let panel {
            slideOut(panel)
        } else {
            panel?.orderOut(nil)
            stopClickMonitor()
        }
    }

    // MARK: – Hot-edge show/hide (no focus transfer)

    private func showFromHotEdge() {
        guard !isVisible, let store,
              store.displayMode == .slideFromRight else { return }
        hotEdgeShown = true

        if panel == nil { buildPanel(store: store) }
        guard let panel, let f = NSScreen.main?.visibleFrame else { return }

        let size     = NSSize(width: Self.width, height: f.height)
        let onFrame  = NSRect(origin: NSPoint(x: f.maxX - Self.width, y: f.minY), size: size)
        let offFrame = NSRect(origin: NSPoint(x: f.maxX,              y: f.minY), size: size)

        panel.setFrame(offFrame, display: false)
        panel.orderFront(nil)   // no activation — user keeps working in their current app

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration       = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(onFrame, display: true)
        }

        startClickMonitor()
    }

    private func hideFromHotEdge() {
        guard isVisible, !(store?.isPinned ?? false) else { return }
        hotEdgeShown = false
        retractTimer = nil

        if let panel {
            slideOut(panel)     // no focus restore — we never stole it
        }
    }

    // MARK: – Panel construction

    private func buildPanel(store: TodoStore) {
        guard let action, let settings else { return }
        let root = ContentView()
            .environmentObject(store)
            .environmentObject(action)
            .environmentObject(settings)
        let host = NSHostingController(rootView: root)

        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.dropHeight),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        p.isOpaque           = false
        p.backgroundColor    = .clear
        p.hasShadow          = true
        p.level              = .popUpMenu
        p.hidesOnDeactivate  = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.contentViewController = host
        panel = p

        // Clicking inside a hot-edge-shown panel (not yet key) activates the app
        // so text fields become interactive without stealing focus on hover.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak p] event in
            if p?.isKeyWindow == false {
                NSApp.activate(ignoringOtherApps: true)
                p?.makeKey()
            }
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
            panel.makeKeyAndOrderFront(nil)
        case .slideFromRight:
            slideIn(panel)
        }
    }

    private func positionBelowStatusItem(_ panel: NSPanel) {
        guard let btn       = statusItem?.button,
              let btnWindow = btn.window else { return }
        let rect = btnWindow.convertToScreen(btn.frame)
        panel.setFrameTopLeftPoint(NSPoint(x: rect.midX - Self.width / 2, y: rect.minY))
    }

    // Uses setFrame (not setFrameOrigin) because borderless NSPanels animate
    // reliably only via the full frame rect.
    private func slideIn(_ panel: NSPanel) {
        guard let f = NSScreen.main?.visibleFrame else { return }
        let size     = NSSize(width: Self.width, height: f.height)
        let onFrame  = NSRect(origin: NSPoint(x: f.maxX - Self.width, y: f.minY), size: size)
        let offFrame = NSRect(origin: NSPoint(x: f.maxX,              y: f.minY), size: size)

        panel.setFrame(offFrame, display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration       = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(onFrame, display: true)
        }
    }

    private func slideOut(_ panel: NSPanel) {
        guard let f = NSScreen.main?.visibleFrame else {
            panel.orderOut(nil); stopClickMonitor(); return
        }
        let offFrame = NSRect(
            origin: NSPoint(x: f.maxX, y: f.minY),
            size:   NSSize(width: Self.width, height: f.height)
        )

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration       = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(offFrame, display: true)
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.stopClickMonitor()
        }
    }

    // MARK: – Hot-edge timer

    // Runs continuously in the background (very cheap); acts only when in
    // slideFromRight mode. Detects edge dwell to trigger show, and mouse-leave
    // to schedule retract.
    private func startEdgeTimer() {
        guard edgeTimer == nil else { return }
        let t = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.pollEdge()
        }
        RunLoop.main.add(t, forMode: .common)
        edgeTimer = t
    }

    private func pollEdge() {
        guard store?.displayMode == .slideFromRight else {
            edgeDwellCount = 0; return
        }
        guard let f = NSScreen.main?.visibleFrame else { return }
        let mouse = NSEvent.mouseLocation

        if !isVisible {
            retractTimer?.invalidate(); retractTimer = nil
            // Require ~0.24 s of dwell at the edge to avoid accidental triggers
            if mouse.x >= f.maxX - 2 && mouse.y >= f.minY && mouse.y <= f.maxY {
                edgeDwellCount += 1
                if edgeDwellCount >= 3 { edgeDwellCount = 0; showFromHotEdge() }
            } else {
                edgeDwellCount = 0
            }
        } else if hotEdgeShown && !(store?.isPinned ?? false) {
            guard let panel else { return }
            // 40pt buffer so the panel doesn't retract the instant the cursor
            // strays slightly outside its edge while scrolling or clicking.
            let expanded = panel.frame.insetBy(dx: -40, dy: -40)
            // Also keep visible if a popover or other app window (e.g. emoji picker)
            // is open and the cursor is inside it.
            let inOtherWindow = NSApp.windows.contains { $0 !== panel && $0.isVisible && $0.frame.contains(mouse) }
            if expanded.contains(mouse) || inOtherWindow {
                retractTimer?.invalidate(); retractTimer = nil
            } else if retractTimer == nil {
                retractTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                    self?.retractTimer = nil
                    self?.hideFromHotEdge()
                }
            }
        }
    }

    // MARK: – Event monitors

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            let mouse = NSEvent.mouseLocation
            // Treat clicks inside any visible app window (panel or popover) as inside.
            let inside = NSApp.windows.contains { $0.isVisible && $0.frame.contains(mouse) }
            if !inside { self.hide() }
        }
    }

    private func stopClickMonitor() {
        clickMonitor.map { NSEvent.removeMonitor($0) }
        clickMonitor = nil
    }
}
