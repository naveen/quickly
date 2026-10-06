import Foundation

public enum ItemKind: String {
    case application = "Application"
    case settings = "System Settings"
    case command = "Command"
    case result = "Result"
}

public enum ItemIcon {
    /// Icon of the file or bundle at this path (apps).
    case file(String)
    /// SF Symbol drawn on a colored tile. Color is an RGB hex like 0x3478F6.
    case symbol(String, tint: UInt32)
    case none
}

public enum ItemAction {
    case openApplication(URL)
    case openURL(URL)
    case copyText(String)
    case perform(() -> Void)
}

public struct LaunchItem {
    public let id: String
    public let title: String
    public let subtitle: String
    public let kind: ItemKind
    public let icon: ItemIcon
    public let action: ItemAction
    public let alternateAction: ItemAction?
    public let keys: [SearchKey]

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        kind: ItemKind,
        icon: ItemIcon,
        action: ItemAction,
        alternateAction: ItemAction? = nil,
        aliases: [String] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.icon = icon
        self.action = action
        self.alternateAction = alternateAction
        var keys = [SearchKey(title)]
        for alias in aliases where alias.caseInsensitiveCompare(title) != .orderedSame {
            keys.append(SearchKey(alias, weight: 85))
        }
        self.keys = keys
    }
}
