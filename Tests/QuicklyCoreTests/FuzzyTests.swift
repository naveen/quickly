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
