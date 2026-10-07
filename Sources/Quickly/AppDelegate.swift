import AppKit
import Carbon
import ServiceManagement
import QuicklyCore

enum SpotlightShortcut {
    /// Reads the "Show Spotlight search" symbolic hotkey (id 64). Missing means enabled.
    static var isEnabled: Bool {
        guard let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys"),
              let entry = all["64"] as? [String: Any]
        else { return true }
        if let enabled = entry["enabled"] as? Bool { return enabled }
        if let enabled = entry["enabled"] as? Int { return enabled != 0 }
        return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let index = SearchIndex()
    private var launcher: LauncherController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let showInMenuBarItem = NSMenuItem(title: "Show in Menu Bar", action: #selector(toggleMenuBar), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        launcher = LauncherController(index: index)
        index.commands = SystemCommands.items(launcher: launcher, index: index)
        index.start()
        registerHotKey()
        if Preferences.showsStatusItem { installStatusItem() }
        warnIfSpotlightOwnsHotKey()
        if CommandLine.arguments.contains("--show") { launcher.show() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "q" }?.value
            switch url.host {
            case "show": launcher.show(query: query)
            case "hide": launcher.hide()
            case "toggle": launcher.toggle()
            case "rescan": index.rescan()
            default: break
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        launcher.show()
        return false
    }

    // MARK: - Hotkey

    private func registerHotKey() {
        let spec = Preferences.hotKey
        guard let combo = HotKey.parse(spec) else {
            NSLog("Quickly: could not parse hotkey '\(spec)', falling back to option+space")
            hotKey = HotKey(keyCode: HotKey.parse("option+space")!.keyCode, modifiers: HotKey.parse("option+space")!.modifiers) { [weak self] in self?.launcher.toggle() }
            return
        }
        hotKey = HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers) { [weak self] in
            self?.launcher.toggle()
        }
        if hotKey == nil {
            NSLog("Quickly: hotkey '\(spec)' is already taken by another app")
        }
    }

    /// ⌘Space is Spotlight's by default. If it is still enabled, Spotlight wins
    /// and Quickly never sees the key, so point the user at the right setting.
    private func warnIfSpotlightOwnsHotKey() {
        guard let combo = HotKey.parse(Preferences.hotKey),
              combo.keyCode == UInt32(kVK_Space), combo.modifiers == UInt32(cmdKey),
              SpotlightShortcut.isEnabled else { return }
        let alert = NSAlert()
        alert.messageText = "Spotlight is still using ⌘ Space"
        alert.informativeText = "Quickly is set to ⌘ Space too, but macOS gives the shortcut to Spotlight.\n\nIn System Settings → Keyboard → Keyboard Shortcuts → Spotlight, turn off “Show Spotlight search”. Or pick another hotkey:\n\ndefaults write com.naveen.quickly hotkey \"option+space\""
        alert.addButton(withTitle: "Open Keyboard Shortcuts")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts")!)
        }
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Quickly")
        item.button?.image?.isTemplate = true
        let menu = NSMenu()
        menu.delegate = self
        let show = NSMenuItem(title: "Open Quickly", action: #selector(showLauncher), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let hotkeyInfo = NSMenuItem(title: "Hotkey: \(HotKey.describe(Preferences.hotKey))", action: nil, keyEquivalent: "")
        hotkeyInfo.isEnabled = false
        menu.addItem(hotkeyInfo)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        showInMenuBarItem.target = self
        menu.addItem(showInMenuBarItem)
        let rescan = NSMenuItem(title: "Rescan Applications", action: #selector(rescan), keyEquivalent: "")
        rescan.target = self
        menu.addItem(rescan)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Quickly", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        showInMenuBarItem.state = Preferences.showsStatusItem ? .on : .off
    }

    @objc private func showLauncher() { launcher.show() }
    @objc private func rescan() { index.rescan() }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nMove Quickly.app to /Applications and try again."
            alert.runModal()
        }
    }

    @objc private func toggleMenuBar() {
        Preferences.showsStatusItem.toggle()
        if Preferences.showsStatusItem {
            installStatusItem()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    /// e.g. "cmd+space", "option+space", "ctrl+`". Change with:
    ///   defaults write com.naveen.quickly hotkey "option+space"
    static var hotKey: String {
        defaults.string(forKey: "hotkey") ?? "cmd+space"
    }

    static var showsStatusItem: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showMenuBarIcon") }
    }

    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Quickly", isDirectory: true)
    }
}
