import Foundation

public struct ScannedApp: Equatable {
    public let url: URL
    public let name: String
    public let bundleID: String?
    public let aliases: [String]
}

public enum AppScanner {
    public static var defaultRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            home.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
            // Safari ships in a cryptex; /Applications/Safari.app is only a
            // hidden symlink to it, which the hidden-file filter skips.
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
        ]
    }

    /// Apps that live outside the normal folders but people expect to find.
    public static let extraApps: [URL] = [
        URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
    ]

    public static func scan(roots: [URL] = defaultRoots, maxDepth: Int = 2) -> [ScannedApp] {
        let fm = FileManager.default
        var seen = Set<String>()
        var out: [ScannedApp] = []

        func add(_ url: URL) {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return }
            seen.insert(path)
            out.append(describe(url))
        }

        func visit(_ dir: URL, depth: Int) {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            for url in entries {
                let resolved = url.resolvingSymlinksInPath()
                if resolved.pathExtension == "app" {
                    add(resolved)
                    continue
                }
                guard depth < maxDepth,
                      let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
                      values.isDirectory == true, values.isPackage != true
                else { continue }
                visit(resolved, depth: depth + 1)
            }
        }

        for root in roots { visit(root, depth: 0) }
        for extra in extraApps where fm.fileExists(atPath: extra.path) { add(extra) }
        return out
    }

    static func describe(_ url: URL) -> ScannedApp {
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }

        var aliases: [String] = []
        let fileName = url.deletingPathExtension().lastPathComponent
        if fileName != name { aliases.append(fileName) }

        var bundleID: String?
        if let bundle = Bundle(url: url) {
            bundleID = bundle.bundleIdentifier
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let value = bundle.object(forInfoDictionaryKey: key) as? String,
                   !value.isEmpty, value != name, !aliases.contains(value) {
                    aliases.append(value)
                }
            }
        }
        return ScannedApp(url: url, name: name, bundleID: bundleID, aliases: aliases)
    }
}
