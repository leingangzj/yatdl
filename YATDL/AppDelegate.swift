// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem:      NSStatusItem!
    private let hotkey           = HotkeyManager()
    let store                    = TodoStore()
    let settings                 = AppSettings()
    let panel                    = PanelController()
    let panelAction              = PanelAction()
    private var settingsWindow:  NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "YATDL")
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
            btn.action = #selector(statusButtonClicked)
            btn.target  = self
        }

        panelAction.hidePanel = { [weak self] in self?.panel.hide() }
        panel.setup(statusItem: statusItem, store: store, settings: settings, action: panelAction)

        hotkey.onHotKey = { [weak self] in self?.panel.toggle() }
        // Option+Space: kVK_Space = 49, optionKey modifier = 0x0800
        hotkey.register(keyCode: kVK_Space, modifiers: UInt32(optionKey))
    }

    // Left-click → toggle panel; right-click → context menu
    @objc private func statusButtonClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            panel.toggle()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About YATDL", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit YATDL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(settings)
                .environmentObject(store)
            let host = NSHostingController(rootView: view)
            host.sizingOptions = .preferredContentSize

            let w = NSWindow(contentViewController: host)
            w.title                  = "YATDL Settings"
            w.styleMask              = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed   = false
            w.titlebarAppearsTransparent = false
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText       = "YATDL"
        alert.informativeText   = "Yet Another To-Do List\nVersion 1.1\n\nBy Zac Leingang\ngithub.com/leingangzj/yatdl\n\nReleased under the MIT License"
        alert.alertStyle        = .informational
        alert.icon              = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: nil)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
