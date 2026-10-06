import AppKit
import QuicklyCore

/// A tiny extension point: given the raw query, return zero or more items that
/// are shown above regular matches. Keep these cheap; they run on every keystroke.
protocol QueryExtension {
    func results(for query: String) -> [LaunchItem]
}

/// "3pm in tokyo", "9:30am pst to ist", "time in london", "sf to berlin".
struct TimeZoneExtension: QueryExtension {
    func results(for query: String) -> [LaunchItem] {
        guard let conversion = TimeZoneQuery.parse(query) else { return [] }
        let (title, subtitle) = TimeZoneQuery.format(conversion)
        return [LaunchItem(
            id: "tz:" + query,
            title: title,
            subtitle: subtitle,
            kind: .result,
            icon: .symbol("globe.americas.fill", tint: 0x30B0C7),
            action: .copyText(title)
        )]
    }
}
