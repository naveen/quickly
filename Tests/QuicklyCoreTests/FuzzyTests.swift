import XCTest
@testable import QuicklyCore

final class FuzzyTests: XCTestCase {
    private func score(_ query: String, _ candidate: String) -> Int? {
        Fuzzy.score(Query(query).bytes, against: SearchKey(candidate))
    }

    func testExactBeatsPrefixBeatsWordPrefix() {
        let exact = score("safari", "Safari")!
        let prefix = score("saf", "Safari")!
        let wordPrefix = score("set", "System Settings")!
        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, wordPrefix)
    }

    func testAcronymMatches() {
        XCTAssertNotNil(score("vsc", "Visual Studio Code"))
        XCTAssertGreaterThan(score("vsc", "Visual Studio Code")!, score("vsc", "Vascular")!)
        XCTAssertNotNil(score("1p", "1Password"))
    }

    func testSeparatorsAndCaseAreIgnored() {
        XCTAssertEqual(score("sys set", "System Settings"), score("sysset", "System Settings"))
        XCTAssertEqual(score("SYSTEM", "System Settings"), score("system", "System Settings"))
        XCTAssertNotNil(score("teams", "Microsoft Teams"))
    }

    func testDiacriticsFold() {
        XCTAssertNotNil(score("cafe", "Café"))
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(score("xyz", "Safari"))
        XCTAssertNil(score("safarii", "Safari"))
        XCTAssertNil(score("", "Safari"))
    }

    func testRankingPrefersBetterTierAndShorterTitle() {
        let items = ["Slack", "Safari", "System Settings", "Sublime Text", "Visual Studio Code"].map {
            LaunchItem(id: $0, title: $0, kind: .application, icon: .none, action: .copyText($0))
        }
        let ranked = Matcher.rank(Query("s"), items: items, usage: nil, limit: 10).map(\.title)
        XCTAssertEqual(ranked.first, "Slack")
        XCTAssertTrue(ranked.contains("Safari"))
        XCTAssertEqual(Matcher.rank(Query("code"), items: items, usage: nil, limit: 10).first?.title, "Visual Studio Code")
        XCTAssertEqual(Matcher.rank(Query("ss"), items: items, usage: nil, limit: 10).first?.title, "System Settings")
    }

    func testUsageBreaksTies() {
        let items = ["Slack", "Safari"].map {
            LaunchItem(id: $0, title: $0, kind: .application, icon: .none, action: .copyText($0))
        }
        let usage = UsageStore(fileURL: nil)
        XCTAssertEqual(Matcher.rank(Query("s"), items: items, usage: usage, limit: 10).first?.title, "Slack")
        usage.record("Safari")
        usage.record("Safari")
        XCTAssertEqual(Matcher.rank(Query("s"), items: items, usage: usage, limit: 10).first?.title, "Safari")
    }
}

final class LearnedRankingTests: XCTestCase {
    private let items = ["Chess", "Google Chrome", "Cheese Maker"].map {
        LaunchItem(id: $0, title: $0, kind: .application, icon: .none, action: .copyText($0))
    }

    private func first(_ q: String, _ usage: UsageStore) -> String? {
        Matcher.rank(Query(q), items: items, usage: usage, limit: 10).first?.title
    }

    func testPrefixWinsBeforeAnyLearning() {
        XCTAssertEqual(first("ch", UsageStore(fileURL: nil)), "Chess")
    }

    func testChoosingAnItemForAQueryIsRemembered() {
        let usage = UsageStore(fileURL: nil)
        usage.record("Google Chrome", query: "ch")
        XCTAssertEqual(first("ch", usage), "Google Chrome")
        XCTAssertEqual(first("CH ", usage), "Google Chrome", "normalised")
    }

    func testLearnedQueryExtendsToLongerQueries() {
        let usage = UsageStore(fileURL: nil)
        usage.record("Google Chrome", query: "ch")
        XCTAssertEqual(first("chr", usage), "Google Chrome")
        // "che" is clearly Chess; Chrome only matches it as a loose subsequence.
        XCTAssertEqual(first("che", usage), "Chess")
    }

    func testLearnedLongerQueryHelpsShorterPrefix() {
        let usage = UsageStore(fileURL: nil)
        usage.record("Google Chrome", query: "chro")
        XCTAssertEqual(first("ch", usage), "Google Chrome")
    }

    func testLatestChoiceOverridesEarlier() {
        let usage = UsageStore(fileURL: nil)
        usage.record("Google Chrome", query: "ch")
        usage.record("Chess", query: "ch")
        XCTAssertEqual(first("ch", usage), "Chess")
    }

    func testHeavyUseCrossesTiersWithoutQueryMemory() {
        let usage = UsageStore(fileURL: nil)
        for _ in 0..<15 { usage.record("Google Chrome") }
        XCTAssertEqual(first("ch", usage), "Google Chrome")
    }

    func testPersistsAndMigratesLegacyFormat() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = dir.appendingPathComponent("usage.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"Chess":{"count":3,"last":0}}"#.utf8).write(to: file)
        let legacy = UsageStore(fileURL: file)
        XCTAssertGreaterThan(legacy.bonus(for: "Chess"), 0)
        legacy.record("Google Chrome", query: "ch")
        // Save is async; give it a moment.
        let expectation = XCTestExpectation()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)
        let reloaded = UsageStore(fileURL: file)
        XCTAssertEqual(reloaded.preferredItemID(for: "ch")?.id, "Google Chrome")
        XCTAssertGreaterThan(reloaded.bonus(for: "Chess"), 0)
    }
}
