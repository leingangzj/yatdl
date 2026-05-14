// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Carbon.HIToolbox

// Registers a process-level global hotkey via the Carbon Event Manager.
// This predates the modern Input Monitoring permission, so no entitlement
// is required for simple hotkey registration (not keystroke capture).
final class HotkeyManager {
    var onHotKey: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register(keyCode: Int, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                DispatchQueue.main.async { mgr.onHotKey?() }
                return noErr
            },
            1, &eventType, ptr, &handlerRef
        )

        // Signature 'YTDL' scopes this hotkey to YATDL so it never collides
        // with another app's Carbon hotkey registration.
        let hkID = EventHotKeyID(signature: 0x5954_444C, id: 1)
        RegisterEventHotKey(
            UInt32(keyCode), modifiers, hkID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }

    deinit {
        if let ref = hotKeyRef  { UnregisterEventHotKey(ref) }
        if let ref = handlerRef { RemoveEventHandler(ref) }
    }
}
