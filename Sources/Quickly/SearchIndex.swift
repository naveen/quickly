import AppKit
import QuicklyCore

/// Owns the list of launchable items, keeps it fresh when app folders change,
/// and caches icons so rendering a result row never touches disk.
final class SearchIndex {
    private(set) var items: [LaunchItem] = []
    private var itemsByID: [String: LaunchItem] = [:]
    let usage: UsageStore
    var commands: [LaunchItem] = [] { didSet { publish(apps: appItems) } }
    var onChange: (() -> Void)?

    private var appItems: [LaunchItem] = []
    private let scanQueue = DispatchQueue(label: "quickly.scan", qos: .userInitiated)
    private var watchers: [DirectoryWatcher] = []
    private var rescanPending = false
    private(set) var lastScan: Date = .distantPast
    private let icons = IconCache()

    init() {
        usage = UsageStore(fileURL: Preferences.appSupportDirectory.appendingPathComponent("usage.json"))
    }

    func start() {
        rescan()
        for root in AppScanner.defaultRoots {
            if let watcher = DirectoryWatcher(url: root, queue: scanQueue, handler: { [weak self] in self?.scheduleRescan() }) {
                watchers.append(watcher)
            }
        }
    }

    func rescan() {
        scanQueue.async { [weak self] in
            guard let self else { return }
            let apps = AppScanner.scan().map(Self.item(for:))
            self.icons.prefetch(apps)
            DispatchQueue.main.async {
                self.lastScan = Date()
                self.publish(apps: apps)
            }
        }
    }

    private func scheduleRescan() {
        // Coalesce bursts of file-system events (e.g. an app install) into one scan.
        guard !rescanPending else { return }
        rescanPending = true
        scanQueue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.rescanPending = false
            self?.rescan()
        }
    }

    private func publish(apps: [LaunchItem]) {
        appItems = apps
        items = apps + settingsItems + commands
        itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        onChange?()
    }

    func item(withID id: String) -> LaunchItem? { itemsByID[id] }

    func icon(for item: LaunchItem) -> NSImage { icons.icon(for: item) }

    func search(_ text: String, extensions: [QueryExtension], limit: Int = 9) -> [LaunchItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return suggestions(limit: 6) }
        var out: [LaunchItem] = []
        for ext in extensions { out += ext.results(for: trimmed) }
        out += Matcher.rank(Query(trimmed), items: items, usage: usage, limit: limit)
        return out
    }

    private func suggestions(limit: Int) -> [LaunchItem] {
        usage.topIDs(limit: limit * 2).compactMap { itemsByID[$0] }.prefix(limit).map { $0 }
    }

    // MARK: - Item construction

    private static func item(for app: ScannedApp) -> LaunchItem {
        LaunchItem(
            id: "app:" + app.url.path,
            title: app.name,
            kind: .application,
            icon: .file(app.url.path),
            action: .openApplication(app.url),
            alternateAction: .perform { NSWorkspace.shared.activateFileViewerSelecting([app.url]) },
            aliases: app.aliases
        )
    }

    private lazy var settingsItems: [LaunchItem] = SettingsCatalog.panes.map { pane in
        LaunchItem(
            id: "settings:" + pane.id,
            title: pane.name,
            kind: .settings,
            icon: .symbol(pane.symbol, tint: pane.tint),
            action: .openURL(pane.url),
            aliases: pane.keywords
        )
    }
}

final class IconCache {
    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()
    static let size = NSSize(width: 24, height: 24)

    func prefetch(_ items: [LaunchItem]) {
        for item in items { _ = icon(for: item) }
    }

    func icon(for item: LaunchItem) -> NSImage {
        lock.lock()
        if let cached = cache[item.id] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let image = render(item.icon)
        lock.lock()
        cache[item.id] = image
        lock.unlock()
        return image
    }

    private func render(_ icon: ItemIcon) -> NSImage {
        switch icon {
        case .file(let path):
            let image = NSWorkspace.shared.icon(forFile: path)
            image.size = IconCache.size
            return image
        case .symbol(let name, let tint):
            return IconCache.tile(symbol: name, tint: tint)
        case .none:
            return NSImage(size: IconCache.size)
        }
    }

    /// A System Settings-style rounded colored tile with a white symbol.
    static func tile(symbol: String, tint: UInt32) -> NSImage {
        let color = NSColor(
            red: CGFloat((tint >> 16) & 0xFF) / 255,
            green: CGFloat((tint >> 8) & 0xFF) / 255,
            blue: CGFloat(tint & 0xFF) / 255,
            alpha: 1
        )
        return NSImage(size: size, flipped: false) { rect in
            let tileRect = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: tileRect, xRadius: 5.5, yRadius: 5.5)
            color.setFill()
            path.fill()
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            if let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let tinted = NSImage(size: base.size, flipped: false) { r in
                    base.draw(in: r)
                    NSColor.white.set()
                    r.fill(using: .sourceAtop)
                    return true
                }
                let s = tinted.size
                let scale = min(14 / max(s.width, 1), 14 / max(s.height, 1), 1)
                let drawSize = NSSize(width: s.width * scale, height: s.height * scale)
                let origin = NSPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
                tinted.draw(in: NSRect(origin: origin, size: drawSize))
            }
            return true
        }
    }
}

final class DirectoryWatcher {
    private let source: DispatchSourceFileSystemObject

    init?(url: URL, queue: DispatchQueue, handler: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: queue)
        source.setEventHandler(handler: handler)
        source.setCancelHandler { close(fd) }
        source.resume()
    }

    deinit { source.cancel() }
}
