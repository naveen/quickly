import AppKit
import QuicklyCore

/// A handful of system actions. Restart/Shut Down/Log Out go through
/// loginwindow so macOS shows its normal confirmation dialog.
enum SystemCommands {
    static func items(launcher: LauncherController, index: SearchIndex) -> [LaunchItem] {
        let gray: UInt32 = 0x636366
        return [
            LaunchItem(id: "cmd:lock", title: "Lock Screen", kind: .command, icon: .symbol("lock.fill", tint: gray),
                       action: .perform(lockScreen), aliases: ["lock"]),
            LaunchItem(id: "cmd:sleep", title: "Sleep", kind: .command, icon: .symbol("moon.zzz.fill", tint: gray),
                       action: .perform { run("/usr/bin/pmset", ["sleepnow"]) }),
            LaunchItem(id: "cmd:displaysleep", title: "Sleep Display", kind: .command, icon: .symbol("display", tint: gray),
                       action: .perform { run("/usr/bin/pmset", ["displaysleepnow"]) }, aliases: ["turn off screen"]),
            LaunchItem(id: "cmd:screensaver", title: "Start Screen Saver", kind: .command, icon: .symbol("sparkles.tv", tint: gray),
                       action: .perform { run("/usr/bin/open", ["-a", "ScreenSaverEngine"]) }),
            LaunchItem(id: "cmd:darkmode", title: "Toggle Dark Mode", kind: .command, icon: .symbol("circle.lefthalf.filled", tint: gray),
                       action: .perform { appleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode") },
                       aliases: ["light mode", "appearance"]),
            LaunchItem(id: "cmd:trash", title: "Empty Trash", kind: .command, icon: .symbol("trash.fill", tint: gray),
                       action: .perform { appleScript("tell application \"Finder\" to empty trash") }),
            LaunchItem(id: "cmd:logout", title: "Log Out…", kind: .command, icon: .symbol("rectangle.portrait.and.arrow.right", tint: gray),
                       action: .perform { appleScript("tell application \"loginwindow\" to «event aevtrlgo»") }),
            LaunchItem(id: "cmd:restart", title: "Restart…", kind: .command, icon: .symbol("arrow.clockwise", tint: gray),
                       action: .perform { appleScript("tell application \"loginwindow\" to «event aevtrrst»") }, aliases: ["reboot"]),
            LaunchItem(id: "cmd:shutdown", title: "Shut Down…", kind: .command, icon: .symbol("power", tint: gray),
                       action: .perform { appleScript("tell application \"loginwindow\" to «event aevtrsdn»") }, aliases: ["power off"]),
            LaunchItem(id: "cmd:rescan", title: "Rescan Applications", subtitle: "Quickly", kind: .command, icon: .symbol("bolt.fill", tint: 0x5E5CE6),
                       action: .perform { index.rescan() }, aliases: ["refresh index"]),
            LaunchItem(id: "cmd:quit", title: "Quit Quickly", subtitle: "Quickly", kind: .command, icon: .symbol("bolt.fill", tint: 0x5E5CE6),
                       action: .perform { NSApp.terminate(nil) }),
        ]
    }

    private static func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run()
    }

    private static func appleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error { NSLog("Quickly: AppleScript failed: \(error)") }
        }
    }

    private static func lockScreen() {
        // Same private call the Lock Screen menu item uses; no permissions needed.
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY),
           let sym = dlsym(handle, "SACLockScreenImmediate") {
            typealias Fn = @convention(c) () -> Int32
            _ = unsafeBitCast(sym, to: Fn.self)()
        } else {
            run("/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession", ["-suspend"])
        }
    }
}
