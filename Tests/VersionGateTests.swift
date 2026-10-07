import XCTest
@testable import AppDatHangIOS

final class VersionGateTests: XCTestCase {
    func testOlderVersionIsOutdated() {
        XCTAssertTrue(VersionGate.isOutdated(current: "1.0.0", minimum: "1.0.1"))
        XCTAssertTrue(VersionGate.isOutdated(current: "1.9.9", minimum: "2.0"))
        XCTAssertTrue(VersionGate.isOutdated(current: "1.0", minimum: "1.0.1"))
    }

    func testSameOrNewerIsNotOutdated() {
        XCTAssertFalse(VersionGate.isOutdated(current: "1.0.1", minimum: "1.0.1"))
        XCTAssertFalse(VersionGate.isOutdated(current: "1.0", minimum: "1.0.0"))
        XCTAssertFalse(VersionGate.isOutdated(current: "1.10.0", minimum: "1.9.0"))
        XCTAssertFalse(VersionGate.isOutdated(current: "2.0.0", minimum: "1.9.9"))
    }

    /// Bản ipa sideload dùng gitSha làm version — không bao giờ được chặn.
    func testNonNumericVersionsNeverBlock() {
        XCTAssertFalse(VersionGate.isOutdated(current: "d867418a", minimum: "9.9.9"))
        XCTAssertFalse(VersionGate.isOutdated(current: "", minimum: "1.0.0"))
        XCTAssertFalse(VersionGate.isOutdated(current: "1.0.0", minimum: "abc"))
        XCTAssertFalse(VersionGate.isOutdated(current: "1.0.0", minimum: ""))
    }

    func testParseRejectsMalformed() {
        XCTAssertNil(VersionGate.parse("1..0"))
        XCTAssertNil(VersionGate.parse("1.0.0.0.0"))
        XCTAssertNil(VersionGate.parse("1.0-beta"))
        XCTAssertEqual(VersionGate.parse("1.2.3"), [1, 2, 3])
    }

    func testPolicyDecodes() throws {
        let json = #"{"toiThieu":"1.0.1","linkAppStore":"https://apps.apple.com/app/id1","thongBao":"Cap nhat"}"#
        let p = try JSONDecoder().decode(AppVersionPolicy.self, from: Data(json.utf8))
        XCTAssertEqual(p.toiThieu, "1.0.1")
        let minimal = try JSONDecoder().decode(AppVersionPolicy.self, from: Data(#"{"toiThieu":"1.0.0"}"#.utf8))
        XCTAssertNil(minimal.linkAppStore)
    }
}
