import AppKit
import Carbon
import LauncherCore

final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context -> OSStatus in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            owner.onPress?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func register(_ shortcut: KeyboardShortcut?) -> Bool {
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        guard let shortcut else { return true }
        let identifier = EventHotKeyID(signature: 0x424C4155, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier, GetApplicationEventTarget(), 0, &reference) == noErr
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }

    static func shortcut(from event: NSEvent) -> KeyboardShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .control, .option]).isEmpty else { return nil }
        var modifiers: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { modifiers |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { modifiers |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey); symbols += "⌘" }
        let names: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        // Strip Option/Control so the label shows the physical key, not its alternate symbol.
        let key = names[event.keyCode] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? ""
        guard !key.isEmpty else { return nil }
        return KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: "\(symbols) \(key)")
    }
}
