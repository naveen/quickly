import AppKit

/// Borderless floating panel that can become key without activating the app,
/// so focus returns to whatever you were doing the moment it closes.
final class LauncherPanel: NSPanel {
    var onCommandNumber: ((Int) -> Bool)?
    var onCommandReturn: (() -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command {
            if event.keyCode == 36 { return onCommandReturn?() ?? false }
            if let chars = event.charactersIgnoringModifiers, let n = Int(chars), (1...9).contains(n) {
                return onCommandNumber?(n) ?? false
            }
            // No main menu in an accessory app, so route the standard editing
            // shortcuts to the field by hand.
            let selector: Selector?
            switch event.charactersIgnoringModifiers {
            case "a": selector = #selector(NSText.selectAll(_:))
            case "c": selector = #selector(NSText.copy(_:))
            case "v": selector = #selector(NSText.paste(_:))
            case "x": selector = #selector(NSText.cut(_:))
            case "z": selector = Selector(("undo:"))
            default: selector = nil
            }
            if let selector { return NSApp.sendAction(selector, to: nil, from: self) }
        }
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "z" {
            return NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Draws a hairline around the rounded panel; vibrancy alone looks unfinished
/// against busy wallpapers.
final class BorderView: NSView {
    var cornerRadius: CGFloat = 14

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        path.lineWidth = 1
        NSColor.separatorColor.withAlphaComponent(0.6).setStroke()
        path.stroke()
    }
}
