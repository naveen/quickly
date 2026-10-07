import Foundation

/// Remembers two things so ranking adapts to the person using it:
/// 1. how often and how recently each item was launched, and
/// 2. which item was chosen for a given query ("ch" → Google Chrome),
///    the way Alfred, Raycast and Quicksilver learn.
public final class UsageStore {
    struct Entry: Codable {
        var count: Int
        var last: Date
    }

    struct Learned: Codable {
        var id: String
        var last: Date
    }

    private struct Store: Codable {
        var items: [String: Entry]
        var queries: [String: Learned]
    }

    private var entries: [String: Entry] = [:]
    private var learned: [String: Learned] = [:]
    private let fileURL: URL?
    private let saveQueue = DispatchQueue(label: "quickly.usage", qos: .utility)
    private static let maxLearnedQueries = 500

    /// Learned pairings only apply to non-exact queries when the item still
    /// matches at least at word-prefix level, so "ch" → Chrome doesn't drag
    /// Chrome above Chess when you type "che".
    public static let learnedMatchThreshold = 600
    public static let learnedBoost = 10_000

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let store = try? decoder.decode(Store.self, from: data) {
            entries = store.items
            learned = store.queries
        } else if let legacy = try? decoder.decode([String: Entry].self, from: data) {
            entries = legacy
        }
    }

    public static func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func record(_ id: String, query: String? = nil, now: Date = Date()) {
        var e = entries[id] ?? Entry(count: 0, last: .distantPast)
        e.count += 1
        e.last = now
        entries[id] = e
        if let query {
            let key = Self.normalize(query)
            if !key.isEmpty {
                learned[key] = Learned(id: id, last: now)
                if learned.count > Self.maxLearnedQueries {
                    let oldest = learned.min { $0.value.last < $1.value.last }?.key
                    if let oldest { learned[oldest] = nil }
                }
            }
        }
        save()
    }

    /// Frequency bonus. Deliberately large enough to lift a daily-use app over
    /// a prefix match on something never launched.
    public func bonus(for id: String, now: Date = Date()) -> Int {
        guard let e = entries[id] else { return 0 }
        let age = now.timeIntervalSince(e.last)
        let recency: Int
        switch age {
        case ..<3600: recency = 40
        case ..<86400: recency = 25
        case ..<(7 * 86400): recency = 12
        case ..<(30 * 86400): recency = 5
        default: recency = 0
        }
        return min(e.count, 20) * 10 + recency
    }

    /// The item previously chosen for this query, if any.
    /// Exact key first; then the longest learned key that is a prefix of the
    /// query ("ch" learned, "chr" typed); then the most recent learned key the
    /// query is a prefix of ("chr" learned, "ch" typed).
    public func preferredItemID(for query: String) -> (id: String, exact: Bool)? {
        let key = Self.normalize(query)
        guard !key.isEmpty, !learned.isEmpty else { return nil }
        if let hit = learned[key] { return (hit.id, true) }

        var bestPrefix: (key: String, id: String)?
        var bestExtension: Learned?
        for (k, v) in learned {
            if key.hasPrefix(k) {
                if bestPrefix == nil || k.count > bestPrefix!.key.count { bestPrefix = (k, v.id) }
            } else if k.hasPrefix(key) {
                if bestExtension == nil || v.last > bestExtension!.last { bestExtension = v }
            }
        }
        if let bestPrefix { return (bestPrefix.id, false) }
        if let bestExtension { return (bestExtension.id, false) }
        return nil
    }

    public func topIDs(limit: Int, now: Date = Date()) -> [String] {
        entries.keys
            .sorted { bonus(for: $0, now: now) > bonus(for: $1, now: now) }
            .prefix(limit)
            .map { $0 }
    }

    public func forget(_ id: String) {
        entries[id] = nil
        learned = learned.filter { $0.value.id != id }
        save()
    }

    private func save() {
        guard let fileURL else { return }
        let snapshot = Store(items: entries, queries: learned)
        saveQueue.async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(snapshot) else { return }
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
