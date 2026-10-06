import XCTest
@testable import QuicklyCore

final class TimeZoneQueryTests: XCTestCase {
    private let la = TimeZone(identifier: "America/Los_Angeles")!
    // 2026-10-06 19:00 UTC == 12:00 PDT
    private let now = Date(timeIntervalSince1970: 1_791_313_200)

    private func parse(_ q: String) -> TimeConversion? {
        TimeZoneQuery.parse(q, now: now, local: la)
    }

    private func hour(_ date: Date, in zone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.component(.hour, from: date)
    }

    func testTimeInZoneFromLocal() throws {
        let c = try XCTUnwrap(parse("3pm in tokyo"))
        XCTAssertEqual(c.targetName, "Tokyo")
        XCTAssertEqual(c.sourceZone.identifier, la.identifier)
        XCTAssertTrue(c.explicitTime)
        XCTAssertEqual(hour(c.date, in: la), 15)
        XCTAssertEqual(hour(c.date, in: c.targetZone), 7)
    }

    func testTimeWithSourceAndTarget() throws {
        let c = try XCTUnwrap(parse("9:30am pst to ist"))
        XCTAssertEqual(c.sourceName, "Los Angeles")
        XCTAssertEqual(c.targetName, "India")
        XCTAssertEqual(hour(c.date, in: c.sourceZone), 9)
        XCTAssertEqual(hour(c.date, in: c.targetZone), 22)
    }

    func testNowInZone() throws {
        for q in ["time in london", "london time", "what time is it in london", "time london"] {
            let c = try XCTUnwrap(parse(q), q)
            XCTAssertEqual(c.targetName, "London", q)
            XCTAssertFalse(c.explicitTime, q)
            XCTAssertEqual(c.date, now, q)
        }
    }

    func testZoneToZoneNow() throws {
        let c = try XCTUnwrap(parse("sf to berlin"))
        XCTAssertEqual(c.sourceName, "Los Angeles")
        XCTAssertEqual(c.targetName, "Berlin")
        XCTAssertFalse(c.explicitTime)
    }

    func testSeparateMeridiemAndMultiWordCity() throws {
        let c = try XCTUnwrap(parse("3 pm in new york"))
        XCTAssertEqual(c.targetName, "New York")
        XCTAssertEqual(hour(c.date, in: la), 15)
    }

    func testOrdinaryQueriesDoNotParse() {
        for q in ["safari", "system settings", "to do", "in design", "time", "time in", "visual studio code", "2024", "3"] {
            XCTAssertNil(parse(q), q)
        }
    }

    func testFormatMentionsDayRollover() throws {
        let c = try XCTUnwrap(parse("11pm in tokyo"))
        let (title, subtitle) = TimeZoneQuery.format(c, now: now, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(title.hasPrefix("3:00 PM in Tokyo"), title)
        XCTAssertTrue(subtitle.contains("tomorrow"), subtitle)
        XCTAssertTrue(subtitle.contains("UTC+9"), subtitle)
    }

    func testTimeParsing() {
        XCTAssertEqual(TimeZoneQuery.parseTime("3pm")?.hour, 15)
        XCTAssertEqual(TimeZoneQuery.parseTime("12am")?.hour, 0)
        XCTAssertEqual(TimeZoneQuery.parseTime("12pm")?.hour, 12)
        XCTAssertEqual(TimeZoneQuery.parseTime("15:45")?.minute, 45)
        XCTAssertEqual(TimeZoneQuery.parseTime("09")?.hour, 9)
        XCTAssertNil(TimeZoneQuery.parseTime("3"))
        XCTAssertNil(TimeZoneQuery.parseTime("25:00"))
        XCTAssertNil(TimeZoneQuery.parseTime("13pm"))
    }
}
