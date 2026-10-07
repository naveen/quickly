import AppKit
import QuicklyCore

/// Glue between the panel, the index, and the extensions.
final class LauncherController: NSObject, NSWindowDelegate {
    static let width: CGFloat = 680

    private let panel: LauncherPanel
    private let viewController = LauncherViewController()
    private let index: SearchIndex
    private let extensions: [QueryExtension] = [TimeZoneExtension()]
    private var results: [LaunchItem] = []

    init(index: SearchIndex) {
        self.index = index
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: LauncherViewController.barHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.contentViewController = viewController
        panel.delegate = self

        viewController.iconProvider = { [index] item in index.icon(for: item) }
        viewController.onQueryChange = { [weak self] text in self?.runQuery(text) }
        viewController.onExecute = { [weak self] item, alternate in self?.execute(item, alternate: alternate) }
        viewController.onEscape = { [weak self] in self?.hide() }
        viewController.setHotKeyHint(HotKey.describe(Preferences.hotKey))
        panel.onCommandNumber = { [weak self] n in
            guard let self, n - 1 < self.results.count else { return false }
            self.execute(self.results[n - 1], alternate: false)
            return true
        }
        panel.onCommandReturn = { [weak self] in
            guard let self, let item = self.viewController.selectedItem else { return false }
            self.execute(item, alternate: true)
            return true
        }
        index.onChange = { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.runQuery(self.viewController.searchField.stringValue)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func show(query: String? = nil) {
        if panel.isVisible, query == nil {
            viewController.focusSearch()
            return
        }
        viewController.reset()
        if let query { viewController.searchField.stringValue = query }
        runQuery(query ?? "")
        panel.makeKeyAndOrderFront(nil)
        viewController.focusSearch()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func runQuery(_ text: String) {
        results = index.search(text, extensions: extensions)
        viewController.results = results
        layout(rows: results.count)
    }

    private func layout(rows: Int) {
        let height = LauncherViewController.height(forRows: rows)
        let screen = targetScreen()
        let visible = screen.visibleFrame
        let top = visible.minY + visible.height * 0.78
        let x = (visible.midX - Self.width / 2).rounded()
        let frame = NSRect(x: x, y: (top - height).rounded(), width: Self.width, height: height)
        panel.setFrame(frame, display: true)
    }

    private func targetScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func execute(_ item: LaunchItem, alternate: Bool) {
        hide()
        if item.kind != .result { index.usage.record(item.id) }
        let action = alternate ? (item.alternateAction ?? item.action) : item.action
        switch action {
        case .openApplication(let url):
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error { NSLog("Quickly: failed to open \(url.path): \(error)") }
            }
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .copyText(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .perform(let block):
            block()
        }
    }
}
