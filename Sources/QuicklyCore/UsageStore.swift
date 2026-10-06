import Foundation

/// Remembers how often and how recently each item was launched so that
/// frequently used items float to the top of otherwise-equal matches.
public final class UsageStore {
    struct Entry: Codable {
        var count: Int
        var last: Date
    }

    private var entries: [String: Entry] = [:]
    private let fileURL: URL?
    private let saveQueue = DispatchQueue(label: "quickly.usage", qos: .utility)

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        }
    }

    public func record(_ id: String, now: Date = Date()) {
        var e = entries[id] ?? Entry(count: 0, last: .distantPast)
        e.count += 1
        e.last = now
        entries[id] = e
        save()
    }

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
        return min(e.count, 12) * 6 + recency
    }

    public func topIDs(limit: Int, now: Date = Date()) -> [String] {
        entries.keys
            .sorted { bonus(for: $0, now: now) > bonus(for: $1, now: now) }
            .prefix(limit)
            .map { $0 }
    }

    public func forget(_ id: String) {
        entries[id] = nil
        save()
    }

    private func save() {
        guard let fileURL else { return }
        let snapshot = entries
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
