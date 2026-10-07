import XCTest
@testable import QuicklyCore

final class AppScannerTests: XCTestCase {
    /// Safari lives in a cryptex and /Applications/Safari.app is a hidden
    /// symlink, so a plain hidden-file-skipping scan of /Applications misses it.
    func testFindsSafari() throws {
        let safari = URL(fileURLWithPath: "/Applications/Safari.app").resolvingSymlinksInPath()
        try XCTSkipUnless(FileManager.default.fileExists(atPath: safari.path), "Safari not installed")
        let apps = AppScanner.scan()
        XCTAssertTrue(apps.contains { $0.bundleID == "com.apple.Safari" }, "Safari missing from scan")
        XCTAssertEqual(apps.filter { $0.bundleID == "com.apple.Safari" }.count, 1, "Safari should appear once")
    }

    func testMissingRootIsIgnored() {
        let apps = AppScanner.scan(roots: [URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")])
        XCTAssertEqual(apps.map(\.name), ["Finder"])
    }
}
