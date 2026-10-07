import Foundation

/// A pre-folded searchable string. Separators are dropped so "sys set" and
/// "sysset" both match "System Settings"; word starts are remembered so
/// prefix-of-word and acronym matches can be rewarded.
public struct SearchKey {
    public let text: [UInt8]
    public let wordStarts: [Bool]
    /// Percentage weight applied to the score (100 = primary title).
    public let weight: Int

    public init(_ string: String, weight: Int = 100) {
        self.weight = weight
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        let original = Array(string.unicodeScalars)
        let scalars = Array(folded.unicodeScalars)
        let aligned = original.count == scalars.count

        var text: [UInt8] = []
        var starts: [Bool] = []
        text.reserveCapacity(scalars.count)
        starts.reserveCapacity(scalars.count)

        var prevSeparator = true
        var prevUpper = false
        for (i, scalar) in scalars.enumerated() {
            if SearchKey.isSeparator(scalar) {
                prevSeparator = true
                prevUpper = false
                continue
            }
            let isUpper = aligned && CharacterSet.uppercaseLetters.contains(original[i])
            var start = prevSeparator
            if !start && isUpper && !prevUpper { start = true } // camelCase boundary
            let utf8 = Array(String(scalar).utf8)
            text.append(utf8[0])
            starts.append(start)
            for extra in utf8.dropFirst() {
                text.append(extra)
                starts.append(false)
            }
            prevSeparator = false
            prevUpper = isUpper
        }
        self.text = text
        self.wordStarts = starts
    }

    static func isSeparator(_ s: Unicode.Scalar) -> Bool {
        switch s {
        case " ", "-", "_", ".", "/", "(", ")", "+", "&", ":", "'", ",", "\u{2019}": return true
        default: return false
        }
    }
}

public struct Query {
    public let raw: String
    public let bytes: [UInt8]

    public init(_ raw: String) {
        self.raw = raw
        let folded = raw.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var s = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars where !SearchKey.isSeparator(scalar) { s.append(scalar) }
        self.bytes = Array(String(s).utf8)
    }

    public var isEmpty: Bool { bytes.isEmpty }
}

public enum Fuzzy {
    /// Returns nil when the query does not match at all. Higher is better.
    /// Tiers: exact (1000) > prefix (~900) > word prefix (~760) > acronym (~650) > subsequence (<400).
    public static func score(_ q: [UInt8], against key: SearchKey) -> Int? {
        let t = key.text
        let n = t.count
        let m = q.count
        if m == 0 || m > n { return nil }

        if n == m {
            return t.elementsEqual(q) ? 1000 : subsequenceScore(q, key)
        }
        if matches(t, at: 0, q) {
            return 900 - min(n - m, 50)
        }

        var i = 1
        while i <= n - m {
            if key.wordStarts[i] && matches(t, at: i, q) {
                return 760 - min(i, 100)
            }
            i += 1
        }

        if m >= 2 {
            var qi = 0
            for j in 0..<n where key.wordStarts[j] {
                if t[j] == q[qi] {
                    qi += 1
                    if qi == m { break }
                }
            }
            if qi == m { return 650 - min(n - m, 50) / 2 }
        }

        return subsequenceScore(q, key)
    }

    @inline(__always)
    private static func matches(_ t: [UInt8], at offset: Int, _ q: [UInt8]) -> Bool {
        if offset + q.count > t.count { return false }
        var k = 0
        while k < q.count {
            if t[offset + k] != q[k] { return false }
            k += 1
        }
        return true
    }

    private static func subsequenceScore(_ q: [UInt8], _ key: SearchKey) -> Int? {
        let t = key.text
        var qi = 0
        var prev = -1
        var gaps = 0
        var starts = 0
        var consecutive = 0
        for j in 0..<t.count where t[j] == q[qi] {
            if key.wordStarts[j] { starts += 1 }
            if prev >= 0 {
                if j == prev + 1 { consecutive += 1 } else { gaps += j - prev - 1 }
            } else {
                gaps += j
            }
            prev = j
            qi += 1
            if qi == q.count { break }
        }
        guard qi == q.count else { return nil }
        let score = 100 + starts * 25 + consecutive * 12 - min(gaps, 80) - min(t.count - q.count, 40) / 2
        return max(score, 1)
    }
}

public enum Matcher {
    public static func rank(_ query: Query, items: [LaunchItem], usage: UsageStore?, limit: Int) -> [LaunchItem] {
        guard !query.isEmpty else { return [] }
        var scored: [(score: Int, index: Int)] = []
        scored.reserveCapacity(32)
        let now = Date()
        let preferred = usage?.preferredItemID(for: query.raw)
        for (i, item) in items.enumerated() {
            var best: Int?
            for key in item.keys {
                if let s = Fuzzy.score(query.bytes, against: key) {
                    let weighted = s * key.weight / 100
                    if best == nil || weighted > best! { best = weighted }
                }
            }
            guard let match = best else { continue }
            var s = match
            if let usage { s += usage.bonus(for: item.id, now: now) }
            if let preferred, preferred.id == item.id,
               preferred.exact || match >= UsageStore.learnedMatchThreshold {
                s += UsageStore.learnedBoost
            }
            scored.append((s, i))
        }
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            let ta = items[a.index].title, tb = items[b.index].title
            if ta.count != tb.count { return ta.count < tb.count }
            return ta < tb
        }
        return scored.prefix(limit).map { items[$0.index] }
    }
}
