import XCTest
@testable import AppDatHangIOS

final class PrefsTests: XCTestCase {
    override func tearDown() {
        Prefs.clear()
        super.tearDown()
    }

    func testIsLoggedInFalseWhenNoToken() {
        Prefs.clear()
        XCTAssertFalse(Prefs.isLoggedIn)
    }

    func testSaveSessionRoundTrips() {
        Prefs.saveSession(token: "t1", refreshToken: "r1", tenKhachHang: "Bảo")
        XCTAssertEqual(Prefs.token, "t1")
        XCTAssertEqual(Prefs.refreshToken, "r1")
        XCTAssertEqual(Prefs.tenKhachHang, "Bảo")
        XCTAssertTrue(Prefs.isLoggedIn)
    }

    func testClearRemovesSession() {
        Prefs.saveSession(token: "t1", refreshToken: "r1", tenKhachHang: "Bảo")
        Prefs.clear()
        XCTAssertNil(Prefs.token)
        XCTAssertNil(Prefs.refreshToken)
        XCTAssertFalse(Prefs.isLoggedIn)
    }

    func testThietBiIdStable() {
        let a = Prefs.thietBiId
        let b = Prefs.thietBiId
        XCTAssertEqual(a, b)
    }
}
