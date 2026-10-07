import Carbon
import Foundation

/// A global keyboard shortcut via Carbon's RegisterEventHotKey. This works
/// without Accessibility permission and fires even when another app is active.
final class HotKey {
    struct Combo {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    private static var registry: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private let handler: () -> Void
    private var ref: EventHotKeyRef?

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: 0x51434B4C /* 'QCKL' */, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else { return nil }
        HotKey.registry[id] = self
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.registry[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            HotKey.registry[hotKeyID.id]?.handler()
            return noErr
        }, 1, &eventType, nil, nil)
    }

    // MARK: - Parsing "option+space"

    private static let modifierNames: [String: UInt32] = [
        "cmd": UInt32(cmdKey), "command": UInt32(cmdKey), "⌘": UInt32(cmdKey),
        "opt": UInt32(optionKey), "option": UInt32(optionKey), "alt": UInt32(optionKey), "⌥": UInt32(optionKey),
        "ctrl": UInt32(controlKey), "control": UInt32(controlKey), "⌃": UInt32(controlKey),
        "shift": UInt32(shiftKey), "⇧": UInt32(shiftKey),
    ]

    private static let keyNames: [String: UInt32] = {
        var k: [String: UInt32] = [
            "space": UInt32(kVK_Space), "return": UInt32(kVK_Return), "enter": UInt32(kVK_Return),
            "tab": UInt32(kVK_Tab), "`": UInt32(kVK_ANSI_Grave), "grave": UInt32(kVK_ANSI_Grave),
            "escape": UInt32(kVK_Escape), "esc": UInt32(kVK_Escape), "-": UInt32(kVK_ANSI_Minus),
            "=": UInt32(kVK_ANSI_Equal), "[": UInt32(kVK_ANSI_LeftBracket), "]": UInt32(kVK_ANSI_RightBracket),
            ";": UInt32(kVK_ANSI_Semicolon), "'": UInt32(kVK_ANSI_Quote), ",": UInt32(kVK_ANSI_Comma),
            ".": UInt32(kVK_ANSI_Period), "/": UInt32(kVK_ANSI_Slash), "\\": UInt32(kVK_ANSI_Backslash),
            "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3), "f4": UInt32(kVK_F4),
            "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6), "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8),
            "f9": UInt32(kVK_F9), "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
        ]
        let letters: [(String, Int)] = [
            ("a", kVK_ANSI_A), ("b", kVK_ANSI_B), ("c", kVK_ANSI_C), ("d", kVK_ANSI_D), ("e", kVK_ANSI_E),
            ("f", kVK_ANSI_F), ("g", kVK_ANSI_G), ("h", kVK_ANSI_H), ("i", kVK_ANSI_I), ("j", kVK_ANSI_J),
            ("k", kVK_ANSI_K), ("l", kVK_ANSI_L), ("m", kVK_ANSI_M), ("n", kVK_ANSI_N), ("o", kVK_ANSI_O),
            ("p", kVK_ANSI_P), ("q", kVK_ANSI_Q), ("r", kVK_ANSI_R), ("s", kVK_ANSI_S), ("t", kVK_ANSI_T),
            ("u", kVK_ANSI_U), ("v", kVK_ANSI_V), ("w", kVK_ANSI_W), ("x", kVK_ANSI_X), ("y", kVK_ANSI_Y),
            ("z", kVK_ANSI_Z),
            ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3), ("4", kVK_ANSI_4),
            ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7), ("8", kVK_ANSI_8), ("9", kVK_ANSI_9),
        ]
        for (name, code) in letters { k[name] = UInt32(code) }
        return k
    }()

    static func parse(_ spec: String) -> Combo? {
        let parts = spec.lowercased().split(whereSeparator: { $0 == "+" || $0 == " " || $0 == "-" }).map(String.init)
        // "-" is also a key name; recover it when the spec ends with it.
        var tokens = parts
        if spec.hasSuffix("-") { tokens.append("-") }
        guard let keyName = tokens.last, let keyCode = keyNames[keyName] else { return nil }
        var modifiers: UInt32 = 0
        for mod in tokens.dropLast() {
            guard let bit = modifierNames[mod] else { return nil }
            modifiers |= bit
        }
        guard modifiers != 0 else { return nil }
        return Combo(keyCode: keyCode, modifiers: modifiers)
    }

    static func describe(_ spec: String) -> String {
        guard let combo = parse(spec) else { return spec }
        var s = ""
        if combo.modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if combo.modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if combo.modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if combo.modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        let keyName = keyNames.first { $0.value == combo.keyCode }?.key ?? "?"
        switch keyName {
        case "space": s += "Space"
        case "return", "enter": s += "↩"
        case "tab": s += "⇥"
        case "escape", "esc": s += "⎋"
        default: s += keyName.uppercased()
        }
        return s
    }
}
