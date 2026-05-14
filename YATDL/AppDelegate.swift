// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkey = HotkeyManager()
    let store  = TodoStore()
    let panel  = PanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .accessory suppresses both the Dock icon and Cmd+Tab entry.
        // LSUIElement in Info.plist handles the same at launch before this fires.
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            // "bolt.circle.fill" — action-oriented bootstrapping iconography
            btn.image  = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "YATDL")
            btn.action = #selector(togglePanel)
            btn.target = self
        }

        panel.setup(statusItem: statusItem, store: store)

        hotkey.onHotKey = { [weak self] in self?.togglePanel() }
        // Option+Space: kVK_Space = 49, optionKey modifier = 0x0800
        hotkey.register(keyCode: kVK_Space, modifiers: UInt32(optionKey))
    }

    @objc func togglePanel() { panel.toggle() }
}
