import Foundation

public struct SettingsPane {
    public let name: String
    /// Extension bundle identifier used by the x-apple.systempreferences: scheme.
    public let id: String
    public let symbol: String
    public let tint: UInt32
    public let keywords: [String]

    public var url: URL { URL(string: "x-apple.systempreferences:\(id)")! }
}

/// System Settings panes on macOS 13+. IDs come from the extension bundles in
/// /System/Library/ExtensionKit/Extensions and open via the
/// x-apple.systempreferences: URL scheme.
public enum SettingsCatalog {
    private static let blue: UInt32 = 0x3478F6
    private static let gray: UInt32 = 0x8E8E93
    private static let red: UInt32 = 0xFF3B30
    private static let orange: UInt32 = 0xFF9500
    private static let green: UInt32 = 0x34C759
    private static let purple: UInt32 = 0xAF52DE
    private static let indigo: UInt32 = 0x5856D6
    private static let teal: UInt32 = 0x30B0C7
    private static let pink: UInt32 = 0xFF2D55
    private static let yellow: UInt32 = 0xFFCC00
    private static let black: UInt32 = 0x1C1C1E

    public static let panes: [SettingsPane] = [
        .init(name: "Wi-Fi", id: "com.apple.wifi-settings-extension", symbol: "wifi", tint: blue, keywords: ["wireless", "network", "internet"]),
        .init(name: "Bluetooth", id: "com.apple.BluetoothSettings", symbol: "wave.3.right", tint: blue, keywords: ["airpods", "devices", "pair"]),
        .init(name: "Network", id: "com.apple.Network-Settings.extension", symbol: "network", tint: blue, keywords: ["ethernet", "dns", "firewall", "proxy"]),
        .init(name: "VPN", id: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", symbol: "lock.shield", tint: blue, keywords: ["network"]),
        .init(name: "Battery", id: "com.apple.Battery-Settings.extension", symbol: "battery.100percent", tint: green, keywords: ["power", "energy", "low power mode", "charging"]),
        .init(name: "General", id: "com.apple.systempreferences.GeneralSettings", symbol: "gearshape", tint: gray, keywords: ["about", "update"]),
        .init(name: "About", id: "com.apple.SystemProfiler.AboutExtension", symbol: "info.circle", tint: gray, keywords: ["this mac", "serial", "version", "memory", "chip"]),
        .init(name: "Software Update", id: "com.apple.Software-Update-Settings.extension", symbol: "arrow.triangle.2.circlepath", tint: gray, keywords: ["macos", "upgrade", "update"]),
        .init(name: "Storage", id: "com.apple.settings.Storage", symbol: "externaldrive", tint: gray, keywords: ["disk", "space", "free up"]),
        .init(name: "AirDrop & Handoff", id: "com.apple.AirDrop-Handoff-Settings.extension", symbol: "airplayaudio", tint: gray, keywords: ["continuity", "universal control"]),
        .init(name: "Login Items & Extensions", id: "com.apple.LoginItems-Settings.extension", symbol: "arrow.right.circle", tint: gray, keywords: ["startup", "launch at login", "background"]),
        .init(name: "Language & Region", id: "com.apple.Localization-Settings.extension", symbol: "globe", tint: blue, keywords: ["locale", "date format", "temperature"]),
        .init(name: "Date & Time", id: "com.apple.Date-Time-Settings.extension", symbol: "clock", tint: blue, keywords: ["clock", "timezone", "24 hour"]),
        .init(name: "Sharing", id: "com.apple.Sharing-Settings.extension", symbol: "square.and.arrow.up", tint: gray, keywords: ["screen sharing", "file sharing", "remote login", "ssh", "hostname"]),
        .init(name: "Time Machine", id: "com.apple.Time-Machine-Settings.extension", symbol: "clock.arrow.circlepath", tint: green, keywords: ["backup"]),
        .init(name: "Transfer or Reset", id: "com.apple.Transfer-Reset-Settings.extension", symbol: "arrow.counterclockwise", tint: gray, keywords: ["erase", "migration assistant"]),
        .init(name: "Startup Disk", id: "com.apple.Startup-Disk-Settings.extension", symbol: "internaldrive", tint: gray, keywords: ["boot", "volume"]),
        .init(name: "Device Management", id: "com.apple.Profiles-Settings.extension", symbol: "checkmark.seal", tint: gray, keywords: ["profiles", "mdm"]),
        .init(name: "Accessibility", id: "com.apple.Accessibility-Settings.extension", symbol: "accessibility", tint: blue, keywords: ["zoom", "voiceover", "display", "pointer", "captions"]),
        .init(name: "Appearance", id: "com.apple.Appearance-Settings.extension", symbol: "circle.lefthalf.filled", tint: black, keywords: ["dark mode", "light mode", "accent color", "theme"]),
        .init(name: "Control Center", id: "com.apple.ControlCenter-Settings.extension", symbol: "switch.2", tint: gray, keywords: ["menu bar", "clock", "battery percentage"]),
        .init(name: "Apple Intelligence & Siri", id: "com.apple.Siri-Settings.extension", symbol: "sparkles", tint: purple, keywords: ["siri", "ai", "voice"]),
        .init(name: "Spotlight", id: "com.apple.Spotlight-Settings.extension", symbol: "magnifyingglass", tint: gray, keywords: ["search", "index", "privacy"]),
        .init(name: "Wallpaper", id: "com.apple.Wallpaper-Settings.extension", symbol: "photo", tint: teal, keywords: ["desktop picture", "background"]),
        .init(name: "Desktop & Dock", id: "com.apple.Desktop-Settings.extension", symbol: "dock.rectangle", tint: black, keywords: ["dock", "stage manager", "mission control", "hot corners", "windows", "default browser"]),
        .init(name: "Displays", id: "com.apple.Displays-Settings.extension", symbol: "display", tint: blue, keywords: ["resolution", "night shift", "brightness", "true tone", "arrangement", "monitor", "refresh rate"]),
        .init(name: "Screen Time", id: "com.apple.Screen-Time-Settings.extension", symbol: "hourglass", tint: indigo, keywords: ["limits", "downtime"]),
        .init(name: "Focus", id: "com.apple.Focus-Settings.extension", symbol: "moon.fill", tint: indigo, keywords: ["do not disturb", "dnd"]),
        .init(name: "Notifications", id: "com.apple.Notifications-Settings.extension", symbol: "bell.badge", tint: red, keywords: ["alerts", "banners", "badges"]),
        .init(name: "Sound", id: "com.apple.Sound-Settings.extension", symbol: "speaker.wave.2", tint: pink, keywords: ["audio", "output", "input", "microphone", "volume", "alert"]),
        .init(name: "Lock Screen", id: "com.apple.Lock-Screen-Settings.extension", symbol: "lock.display", tint: black, keywords: ["screen saver", "require password", "sleep"]),
        .init(name: "Privacy & Security", id: "com.apple.settings.PrivacySecurity.extension", symbol: "hand.raised", tint: blue, keywords: ["accessibility permissions", "filevault", "camera", "microphone", "full disk access", "screen recording", "gatekeeper"]),
        .init(name: "Touch ID & Password", id: "com.apple.Touch-ID-Settings.extension", symbol: "touchid", tint: red, keywords: ["fingerprint", "login password"]),
        .init(name: "Users & Groups", id: "com.apple.Users-Groups-Settings.extension", symbol: "person.2", tint: blue, keywords: ["accounts", "guest", "admin"]),
        .init(name: "Internet Accounts", id: "com.apple.Internet-Accounts-Settings.extension", symbol: "at", tint: blue, keywords: ["mail", "google", "icloud", "exchange"]),
        .init(name: "Apple Account", id: "com.apple.systempreferences.AppleIDSettings", symbol: "apple.logo", tint: gray, keywords: ["icloud", "apple id", "subscriptions"]),
        .init(name: "Family", id: "com.apple.Family-Settings.extension", symbol: "figure.2.and.child.holdinghands", tint: blue, keywords: ["sharing", "kids"]),
        .init(name: "Game Center", id: "com.apple.Game-Center-Settings.extension", symbol: "gamecontroller", tint: gray, keywords: ["games"]),
        .init(name: "Wallet & Apple Pay", id: "com.apple.WalletSettingsExtension", symbol: "creditcard", tint: black, keywords: ["cards", "payment"]),
        .init(name: "Keyboard", id: "com.apple.Keyboard-Settings.extension", symbol: "keyboard", tint: gray, keywords: ["shortcuts", "input sources", "text replacement", "dictation", "key repeat", "modifier keys", "function keys"]),
        .init(name: "Mouse", id: "com.apple.Mouse-Settings.extension", symbol: "computermouse", tint: gray, keywords: ["tracking speed", "scroll", "natural scrolling"]),
        .init(name: "Trackpad", id: "com.apple.Trackpad-Settings.extension", symbol: "rectangle.and.hand.point.up.left", tint: gray, keywords: ["gestures", "tap to click", "tracking speed", "force click"]),
        .init(name: "Game Controllers", id: "com.apple.Game-Controller-Settings.extension", symbol: "gamecontroller.fill", tint: gray, keywords: ["gamepad", "xbox", "playstation"]),
        .init(name: "Printers & Scanners", id: "com.apple.Print-Scan-Settings.extension", symbol: "printer", tint: gray, keywords: ["print", "scan", "airprint"]),
        .init(name: "Headphones", id: "com.apple.HeadphoneSettings", symbol: "headphones", tint: gray, keywords: ["airpods", "audio"]),
        .init(name: "CDs & DVDs", id: "com.apple.CD-DVD-Settings.extension", symbol: "opticaldisc", tint: gray, keywords: ["disc"]),
        .init(name: "Coverage", id: "com.apple.Coverage-Settings.extension", symbol: "checkmark.shield", tint: gray, keywords: ["applecare", "warranty"]),
    ]
}
