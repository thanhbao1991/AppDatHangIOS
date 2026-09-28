import XCTest
@testable import AppDatHangIOS

final class PrefsTests: XCTestCase {
    override func tearDown() {
        Prefs.clear()
        // clear() không còn xoá thongBaoLastSeen (đổi 2026-09-29, xem property) — dọn tay các khoá
        // theo khachHangId dùng trong test ở đây để không rò rỉ sang lượt chạy test khác.
        UserDefaults.standard.removeObject(forKey: "thongBaoLastSeen_kh-A")
        UserDefaults.standard.removeObject(forKey: "thongBaoLastSeen_kh-B")
        UserDefaults.standard.removeObject(forKey: "thongBaoLastSeen_anon")
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

    // Bug đã fix 2026-09-29 (feedback "login vào lúc nào badge cũng 50, bấm vào thì mất nhưng login
    // vào lại thấy 50"): clear() (gọi lúc đăng xuất) từng XOÁ LUÔN mốc "đã xem thông báo" — đăng
    // xuất/đăng nhập lại CHÍNH tài khoản đó (không đổi khách) làm toàn bộ lịch sử hiện lại "chưa
    // đọc". Giờ mốc khoá theo khachHangId nên phải SỐNG SÓT qua đăng xuất/đăng nhập lại cùng khách.
    func testThongBaoLastSeen_SongSotQuaDangXuatDangNhapLaiCungKhach() {
        Prefs.saveSession(token: "t1", refreshToken: "r1", khachHangId: "kh-A", tenKhachHang: "Bảo")
        Prefs.thongBaoLastSeen = "2026-09-29T10:00:00"

        Prefs.clear()
        Prefs.saveSession(token: "t2", refreshToken: "r2", khachHangId: "kh-A", tenKhachHang: "Bảo")

        XCTAssertEqual(Prefs.thongBaoLastSeen, "2026-09-29T10:00:00")
    }

    // Đổi SANG TÀI KHOẢN KHÁC trên cùng máy thì KHÔNG được thấy mốc "đã xem" của tài khoản trước —
    // đây là bug GỐC (2026-09-14) mà bản sửa lần đầu (xoá mốc lúc đăng xuất) từng vá đúng, không được
    // để fix lần này (không xoá nữa) làm SỐNG LẠI bug cũ.
    func testThongBaoLastSeen_TachRiengGiuaHaiTaiKhoanKhacNhau() {
        Prefs.saveSession(token: "t1", refreshToken: "r1", khachHangId: "kh-A", tenKhachHang: "Bảo")
        Prefs.thongBaoLastSeen = "2026-09-29T10:00:00"

        Prefs.clear()
        Prefs.saveSession(token: "t2", refreshToken: "r2", khachHangId: "kh-B", tenKhachHang: "Khách Khác")

        XCTAssertNil(Prefs.thongBaoLastSeen)
    }
}
