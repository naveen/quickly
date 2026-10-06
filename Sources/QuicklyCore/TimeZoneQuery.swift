import Foundation

public struct TimeConversion {
    public let sourceZone: TimeZone
    public let sourceName: String
    public let targetZone: TimeZone
    public let targetName: String
    /// The instant being described.
    public let date: Date
    /// True when the user typed a specific clock time rather than "now".
    public let explicitTime: Bool
}

/// Parses things like "3pm in tokyo", "9:30am pst to ist", "time in london",
/// "tokyo time", "sf to berlin". Returns nil for anything that doesn't look
/// like a time-zone question, so ordinary app searches never trigger it.
public enum TimeZoneQuery {
    struct Zone {
        let zone: TimeZone
        let name: String
    }

    private static let fillers: Set<String> = [
        "what", "whats", "what's", "the", "is", "it", "at", "o'clock", "current", "currently",
        "convert", "now", "right", "time", "times", "zone", "timezone", "tz", "clock", "of", "here?",
    ]
    private static let separators: Set<String> = ["in", "to", "->", "→", "="]

    public static func parse(_ raw: String, now: Date = Date(), local: TimeZone = .current) -> TimeConversion? {
        let lowered = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens = lowered.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "?" }).map(String.init)
        guard !tokens.isEmpty, tokens.count <= 8 else { return nil }

        // Merge "3 pm" into "3pm".
        var merged: [String] = []
        var i = 0
        while i < tokens.count {
            let tok = tokens[i]
            if i + 1 < tokens.count, (tokens[i + 1] == "am" || tokens[i + 1] == "pm"), parseTime(tok + tokens[i + 1]) != nil {
                merged.append(tok + tokens[i + 1])
                i += 2
            } else {
                merged.append(tok)
                i += 1
            }
        }
        tokens = merged

        let hasTimeWord = tokens.contains { $0 == "time" || $0 == "timezone" || $0 == "clock" }
        let timeIndex = tokens.firstIndex { parseTime($0) != nil }
        let hasSeparator = tokens.contains { separators.contains($0) }
        guard timeIndex != nil || hasTimeWord || hasSeparator else { return nil }

        var sourceTokens: [String] = []
        var targetTokens: [String] = []
        var clock: (hour: Int, minute: Int)?

        if let ti = timeIndex {
            clock = parseTime(tokens[ti])
            let before = clean(Array(tokens[..<ti]))
            let after = Array(tokens[(ti + 1)...])
            if let si = after.firstIndex(where: { separators.contains($0) }) {
                sourceTokens = clean(Array(after[..<si]))
                targetTokens = clean(Array(after[(si + 1)...]))
            } else {
                targetTokens = clean(after)
            }
            if sourceTokens.isEmpty { sourceTokens = before }
        } else if let si = tokens.firstIndex(where: { separators.contains($0) }) {
            sourceTokens = clean(Array(tokens[..<si]))
            targetTokens = clean(Array(tokens[(si + 1)...]))
        } else {
            targetTokens = clean(tokens)
        }

        guard !targetTokens.isEmpty, let target = lookup(targetTokens, local: local) else { return nil }
        let source: Zone
        if sourceTokens.isEmpty {
            source = Zone(zone: local, name: "here")
        } else if let s = lookup(sourceTokens, local: local) {
            source = s
        } else {
            return nil
        }

        var date = now
        if let clock {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = source.zone
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = clock.hour
            comps.minute = clock.minute
            guard let d = cal.date(from: comps) else { return nil }
            date = d
        }

        return TimeConversion(
            sourceZone: source.zone, sourceName: source.name,
            targetZone: target.zone, targetName: target.name,
            date: date, explicitTime: clock != nil
        )
    }

    /// Title and subtitle for a result row.
    public static func format(_ c: TimeConversion, now: Date = Date(), locale: Locale = .current) -> (title: String, subtitle: String) {
        let targetTime = timeString(c.date, in: c.targetZone, locale: locale)
        let targetAbbr = abbreviation(c.targetZone, at: c.date, locale: locale)
        let title = "\(targetTime) in \(c.targetName)\(targetAbbr.isEmpty ? "" : " (\(targetAbbr))")"

        var parts: [String] = []
        if c.explicitTime {
            let sourceTime = timeString(c.date, in: c.sourceZone, locale: locale)
            let sourceAbbr = abbreviation(c.sourceZone, at: c.date, locale: locale)
            parts.append("\(sourceTime) \(c.sourceName)\(sourceAbbr.isEmpty ? "" : " (\(sourceAbbr))")")
        } else {
            parts.append("Now")
        }
        if let delta = dayDelta(c.date, from: c.sourceZone, to: c.targetZone) { parts.append(delta) }
        parts.append(offsetString(c.targetZone, at: c.date))
        let diff = c.targetZone.secondsFromGMT(for: c.date) - c.sourceZone.secondsFromGMT(for: c.date)
        if diff != 0 { parts.append(hoursString(diff) + (c.explicitTime ? "" : " from here")) }
        return (title, parts.joined(separator: " · "))
    }

    // MARK: - Helpers

    static func clean(_ tokens: [String]) -> [String] {
        tokens.filter { !fillers.contains($0) && !separators.contains($0) }
    }

    static func parseTime(_ token: String) -> (hour: Int, minute: Int)? {
        var t = token
        var meridiem: String?
        if t.hasSuffix("am") || t.hasSuffix("pm") {
            meridiem = String(t.suffix(2))
            t = String(t.dropLast(2))
        }
        guard !t.isEmpty, t.allSatisfy({ $0.isNumber || $0 == ":" || $0 == "." }) else { return nil }
        let parts = t.split(whereSeparator: { $0 == ":" || $0 == "." }).map(String.init)
        guard parts.count == 1 || parts.count == 2, let h = Int(parts[0]) else { return nil }
        var minute = 0
        if parts.count == 2 {
            guard parts[1].count == 2, let m = Int(parts[1]), (0...59).contains(m) else { return nil }
            minute = m
        } else if meridiem == nil {
            // A bare number like "3" or "2024" is too ambiguous to be a time.
            guard token.count <= 2, parts[0].count == 2 else { return nil }
        }
        var hour = h
        if let meridiem {
            guard (1...12).contains(h) else { return nil }
            if meridiem == "pm" && h != 12 { hour = h + 12 }
            if meridiem == "am" && h == 12 { hour = 0 }
        } else {
            guard (0...23).contains(h) else { return nil }
        }
        return (hour, minute)
    }

    static func lookup(_ tokens: [String], local: TimeZone) -> Zone? {
        let phrase = tokens.joined(separator: " ")
        if phrase == "local" || phrase == "here" || phrase == "me" || phrase == "my" {
            return Zone(zone: local, name: "here")
        }
        if let z = table[phrase] { return z }
        // Allow a trailing/leading descriptive word to be dropped: "tokyo japan".
        if tokens.count > 1 {
            if let z = table[tokens.dropFirst().joined(separator: " ")] { return z }
            if let z = table[tokens.dropLast().joined(separator: " ")] { return z }
        }
        // Raw identifier like "America/New_York".
        if phrase.contains("/"), let tz = TimeZone(identifier: tokens.joined(separator: "_").capitalizedIdentifier) {
            return Zone(zone: tz, name: tz.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? tz.identifier)
        }
        return nil
    }

    /// "PDT", "JST"… or empty when the zone only has a "GMT+9" style name,
    /// since the UTC offset is shown separately anyway.
    static func abbreviation(_ zone: TimeZone, at date: Date, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = zone
        f.dateFormat = "zzz"
        let abbr = f.string(from: date)
        return abbr.hasPrefix("GMT") || abbr.hasPrefix("UTC") ? "" : abbr
    }

    static func timeString(_ date: Date, in zone: TimeZone, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = zone
        f.setLocalizedDateFormatFromTemplate("jmm")
        // Recent macOS inserts a narrow no-break space before AM/PM; plain
        // spaces paste more predictably.
        return f.string(from: date).replacingOccurrences(of: "\u{202F}", with: " ")
    }

    static func dayDelta(_ date: Date, from source: TimeZone, to target: TimeZone) -> String? {
        func dayNumber(_ zone: TimeZone) -> Int {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = zone
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let midnight = utc.date(from: comps) ?? date
            return Int(midnight.timeIntervalSince1970 / 86400)
        }
        let delta = dayNumber(target) - dayNumber(source)
        switch delta {
        case 0: return nil
        case 1: return "tomorrow"
        case -1: return "yesterday"
        default:
            let f = DateFormatter()
            f.timeZone = target
            f.setLocalizedDateFormatFromTemplate("EEE MMM d")
            return f.string(from: date)
        }
    }

    static func offsetString(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        if seconds == 0 { return "UTC" }
        let sign = seconds < 0 ? "-" : "+"
        let abs = Swift.abs(seconds)
        let h = abs / 3600
        let m = (abs % 3600) / 60
        return m == 0 ? "UTC\(sign)\(h)" : "UTC\(sign)\(h):\(String(format: "%02d", m))"
    }

    static func hoursString(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let abs = Swift.abs(seconds)
        let h = abs / 3600
        let m = (abs % 3600) / 60
        let value = m == 0 ? "\(h)" : "\(h).5"
        return "\(sign)\(value)h"
    }

    // MARK: - Zone table

    static let table: [String: Zone] = buildTable()

    private static func buildTable() -> [String: Zone] {
        var t: [String: Zone] = [:]
        for id in TimeZone.knownTimeZoneIdentifiers {
            let comps = id.split(separator: "/")
            guard comps.count >= 2, comps.first != "Etc", let tz = TimeZone(identifier: id) else { continue }
            let name = String(comps.last!).replacingOccurrences(of: "_", with: " ")
            let key = name.lowercased()
            if t[key] == nil { t[key] = Zone(zone: tz, name: name) }
        }
        if let utc = TimeZone(identifier: "UTC") {
            for k in ["utc", "gmt", "zulu", "z"] { t[k] = Zone(zone: utc, name: "UTC") }
        }
        let aliases: [(keys: [String], id: String, name: String)] = [
            (["nyc", "ny", "new york", "est", "edt", "et", "eastern", "boston", "miami", "atlanta", "washington", "dc", "toronto", "montreal"], "America/New_York", "New York"),
            (["sf", "san francisco", "la", "los angeles", "pst", "pdt", "pt", "pacific", "seattle", "california", "portland", "san diego", "vancouver", "cupertino", "silicon valley", "bay area"], "America/Los_Angeles", "Los Angeles"),
            (["cst", "cdt", "ct", "central", "chicago", "austin", "dallas", "houston", "minneapolis", "mexico city"], "America/Chicago", "Chicago"),
            (["mst", "mdt", "mt", "mountain", "denver", "salt lake city", "boulder"], "America/Denver", "Denver"),
            (["arizona", "phoenix"], "America/Phoenix", "Phoenix"),
            (["hawaii", "honolulu", "hst"], "Pacific/Honolulu", "Honolulu"),
            (["alaska", "anchorage", "akst", "akdt"], "America/Anchorage", "Anchorage"),
            (["london", "uk", "england", "britain", "bst"], "Europe/London", "London"),
            (["dublin", "ireland"], "Europe/Dublin", "Dublin"),
            (["lisbon", "portugal"], "Europe/Lisbon", "Lisbon"),
            (["berlin", "germany", "cet", "cest", "munich", "frankfurt", "hamburg"], "Europe/Berlin", "Berlin"),
            (["paris", "france"], "Europe/Paris", "Paris"),
            (["amsterdam", "netherlands"], "Europe/Amsterdam", "Amsterdam"),
            (["madrid", "spain", "barcelona"], "Europe/Madrid", "Madrid"),
            (["rome", "italy", "milan"], "Europe/Rome", "Rome"),
            (["zurich", "switzerland", "geneva"], "Europe/Zurich", "Zurich"),
            (["stockholm", "sweden"], "Europe/Stockholm", "Stockholm"),
            (["oslo", "norway"], "Europe/Oslo", "Oslo"),
            (["copenhagen", "denmark"], "Europe/Copenhagen", "Copenhagen"),
            (["helsinki", "finland", "eet", "eest"], "Europe/Helsinki", "Helsinki"),
            (["warsaw", "poland"], "Europe/Warsaw", "Warsaw"),
            (["prague", "czechia"], "Europe/Prague", "Prague"),
            (["vienna", "austria"], "Europe/Vienna", "Vienna"),
            (["athens", "greece"], "Europe/Athens", "Athens"),
            (["istanbul", "turkey"], "Europe/Istanbul", "Istanbul"),
            (["kyiv", "kiev", "ukraine"], "Europe/Kyiv", "Kyiv"),
            (["moscow", "russia", "msk"], "Europe/Moscow", "Moscow"),
            (["tel aviv", "israel", "jerusalem"], "Asia/Jerusalem", "Tel Aviv"),
            (["dubai", "uae", "gst", "abu dhabi"], "Asia/Dubai", "Dubai"),
            (["riyadh", "saudi"], "Asia/Riyadh", "Riyadh"),
            (["cairo", "egypt"], "Africa/Cairo", "Cairo"),
            (["lagos", "nigeria", "wat"], "Africa/Lagos", "Lagos"),
            (["nairobi", "kenya", "eat"], "Africa/Nairobi", "Nairobi"),
            (["johannesburg", "south africa", "cape town", "sast"], "Africa/Johannesburg", "Johannesburg"),
            (["ist", "india", "bangalore", "bengaluru", "mumbai", "delhi", "new delhi", "hyderabad", "chennai", "pune", "kolkata"], "Asia/Kolkata", "India"),
            (["karachi", "pakistan", "pkt"], "Asia/Karachi", "Karachi"),
            (["dhaka", "bangladesh"], "Asia/Dhaka", "Dhaka"),
            (["bangkok", "thailand", "ict"], "Asia/Bangkok", "Bangkok"),
            (["jakarta", "indonesia", "wib"], "Asia/Jakarta", "Jakarta"),
            (["singapore", "sg", "sgt"], "Asia/Singapore", "Singapore"),
            (["kuala lumpur", "malaysia"], "Asia/Kuala_Lumpur", "Kuala Lumpur"),
            (["manila", "philippines", "pht"], "Asia/Manila", "Manila"),
            (["hong kong", "hk", "hkt"], "Asia/Hong_Kong", "Hong Kong"),
            (["taipei", "taiwan"], "Asia/Taipei", "Taipei"),
            (["beijing", "china", "shanghai", "shenzhen", "cn"], "Asia/Shanghai", "Beijing"),
            (["tokyo", "japan", "jst", "osaka"], "Asia/Tokyo", "Tokyo"),
            (["seoul", "korea", "kst"], "Asia/Seoul", "Seoul"),
            (["sydney", "australia", "aest", "aedt", "canberra"], "Australia/Sydney", "Sydney"),
            (["melbourne"], "Australia/Melbourne", "Melbourne"),
            (["brisbane"], "Australia/Brisbane", "Brisbane"),
            (["perth", "awst"], "Australia/Perth", "Perth"),
            (["auckland", "nz", "new zealand", "nzst", "nzdt", "wellington"], "Pacific/Auckland", "Auckland"),
            (["sao paulo", "brazil", "brt"], "America/Sao_Paulo", "São Paulo"),
            (["buenos aires", "argentina"], "America/Argentina/Buenos_Aires", "Buenos Aires"),
            (["santiago", "chile"], "America/Santiago", "Santiago"),
            (["bogota", "colombia"], "America/Bogota", "Bogotá"),
            (["lima", "peru"], "America/Lima", "Lima"),
        ]
        for alias in aliases {
            guard let tz = TimeZone(identifier: alias.id) else { continue }
            for key in alias.keys { t[key] = Zone(zone: tz, name: alias.name) }
        }
        return t
    }
}

private extension String {
    /// "america/new_york" → "America/New_York"
    var capitalizedIdentifier: String {
        split(separator: "/").map { part in
            part.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "_")
        }.joined(separator: "/")
    }
}
