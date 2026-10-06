import AppKit
import QuicklyCore

final class LauncherViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let barHeight: CGFloat = 60
    static let rowHeight: CGFloat = 48
    static let maxVisibleRows = 8
    static let cornerRadius: CGFloat = 14

    let searchField = NSTextField()
    let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let separator = NSBox()
    private let hintLabel = NSTextField(labelWithString: "")

    var results: [LaunchItem] = [] {
        didSet {
            tableView.reloadData()
            if !results.isEmpty { tableView.selectRowIndexes([0], byExtendingSelection: false) }
            separator.isHidden = results.isEmpty
            scrollView.isHidden = results.isEmpty
        }
    }
    var iconProvider: ((LaunchItem) -> NSImage)?
    var onQueryChange: ((String) -> Void)?
    var onExecute: ((LaunchItem, _ alternate: Bool) -> Void)?
    var onEscape: (() -> Void)?

    var selectedItem: LaunchItem? {
        let row = tableView.selectedRow
        return row >= 0 && row < results.count ? results[row] : nil
    }

    override func loadView() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.maskImage = Self.roundedMask(radius: Self.cornerRadius)

        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 24, weight: .regular)
        searchField.placeholderString = "Search apps, settings…"
        searchField.delegate = self
        searchField.cell?.sendsActionOnEndEditing = false
        searchField.cell?.isScrollable = true
        searchField.cell?.wraps = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(searchField)

        hintLabel.font = .systemFont(ofSize: 11, weight: .medium)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .right
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(hintLabel)

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)

        let column = NSTableColumn(identifier: .init("result"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = Self.rowHeight
        tableView.intercellSpacing = .zero
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.allowsMultipleSelection = false
        tableView.style = .plain
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.refusesFirstResponder = true

        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        let border = BorderView()
        border.cornerRadius = Self.cornerRadius
        border.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(border)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: hintLabel.leadingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: root.topAnchor, constant: Self.barHeight / 2),

            hintLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            hintLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            hintLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            separator.topAnchor.constraint(equalTo: root.topAnchor, constant: Self.barHeight),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor, constant: Self.barHeight + 1),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            border.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            border.topAnchor.constraint(equalTo: root.topAnchor),
            border.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        hintLabel.setContentHuggingPriority(.required, for: .horizontal)
        hintLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        view = root
    }

    func setHotKeyHint(_ text: String) { hintLabel.stringValue = text }

    func reset() {
        searchField.stringValue = ""
    }

    func focusSearch() {
        view.window?.makeFirstResponder(searchField)
        if let editor = searchField.currentEditor() {
            editor.selectedRange = NSRange(location: editor.string.count, length: 0)
        }
    }

    static func height(forRows rows: Int) -> CGFloat {
        guard rows > 0 else { return barHeight }
        return barHeight + 1 + CGFloat(min(rows, maxVisibleRows)) * rowHeight + 8
    }

    // MARK: - Text field

    func controlTextDidChange(_ obj: Notification) {
        onQueryChange?(searchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            if let item = selectedItem { onExecute?(item, false) }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if searchField.stringValue.isEmpty {
                onEscape?()
            } else {
                searchField.stringValue = ""
                onQueryChange?("")
            }
            return true
        case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
            return true
        case #selector(NSResponder.moveToBeginningOfDocument(_:)), #selector(NSResponder.scrollToBeginningOfDocument(_:)):
            selectRow(0)
            return true
        case #selector(NSResponder.moveToEndOfDocument(_:)), #selector(NSResponder.scrollToEndOfDocument(_:)):
            selectRow(results.count - 1)
            return true
        case #selector(NSResponder.pageDown(_:)):
            moveSelection(by: Self.maxVisibleRows)
            return true
        case #selector(NSResponder.pageUp(_:)):
            moveSelection(by: -Self.maxVisibleRows)
            return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let current = max(tableView.selectedRow, 0)
        selectRow(min(max(current + delta, 0), results.count - 1))
    }

    func selectRow(_ row: Int) {
        guard row >= 0, row < results.count else { return }
        tableView.selectRowIndexes([row], byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    @objc private func rowClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < results.count else { return }
        onExecute?(results[row], NSEvent.modifierFlags.contains(.command))
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let id = NSUserInterfaceItemIdentifier("row")
        let view = tableView.makeView(withIdentifier: id, owner: nil) as? ResultRowView ?? ResultRowView()
        view.identifier = id
        return view
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? ResultCellView ?? ResultCellView()
        cell.identifier = id
        let item = results[row]
        cell.configure(item: item, icon: iconProvider?(item), shortcut: row < 9 ? "⌘\(row + 1)" : "")
        return cell
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

final class ResultRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let rect = bounds.insetBy(dx: 8, dy: 1)
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
    }
}

final class ResultCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let kindLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        kindLabel.font = .systemFont(ofSize: 12)
        kindLabel.textColor = .tertiaryLabelColor
        kindLabel.alignment = .right
        shortcutLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        shortcutLabel.textColor = .tertiaryLabelColor
        shortcutLabel.alignment = .right
        for v in [iconView, titleLabel, subtitleLabel, kindLabel, shortcutLabel] { addSubview(v) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(item: LaunchItem, icon: NSImage?, shortcut: String) {
        iconView.image = icon
        titleLabel.stringValue = item.title
        subtitleLabel.stringValue = item.subtitle
        kindLabel.stringValue = item.subtitle.isEmpty || item.kind != .result ? item.kind.rawValue : ""
        shortcutLabel.stringValue = shortcut
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let iconSize: CGFloat = 30
        iconView.frame = NSRect(x: 20, y: (h - iconSize) / 2, width: iconSize, height: iconSize)

        shortcutLabel.sizeToFit()
        let shortcutWidth: CGFloat = shortcutLabel.stringValue.isEmpty ? 0 : 30
        shortcutLabel.frame = NSRect(x: bounds.width - 20 - shortcutWidth, y: (h - shortcutLabel.frame.height) / 2,
                                     width: shortcutWidth, height: shortcutLabel.frame.height)

        kindLabel.sizeToFit()
        let kindWidth = kindLabel.frame.width
        let kindX = shortcutLabel.frame.minX - (shortcutWidth > 0 ? 12 : 0) - kindWidth
        kindLabel.frame = NSRect(x: kindX, y: (h - kindLabel.frame.height) / 2, width: kindWidth, height: kindLabel.frame.height)

        let textLeft: CGFloat = 62
        let textRight = kindX - 12
        titleLabel.sizeToFit()
        let titleWidth = min(titleLabel.frame.width, textRight - textLeft)
        titleLabel.frame = NSRect(x: textLeft, y: (h - titleLabel.frame.height) / 2, width: max(titleWidth, 0), height: titleLabel.frame.height)

        if subtitleLabel.stringValue.isEmpty {
            subtitleLabel.frame = .zero
        } else {
            subtitleLabel.sizeToFit()
            let x = titleLabel.frame.maxX + 10
            subtitleLabel.frame = NSRect(x: x, y: (h - subtitleLabel.frame.height) / 2 - 0.5,
                                         width: max(textRight - x, 0), height: subtitleLabel.frame.height)
        }
    }
}
