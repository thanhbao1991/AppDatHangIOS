import XCTest
@testable import AppDatHangIOS

final class NoiDungTests: XCTestCase {
    // Chưa tải được từ backend vẫn phải có câu mặc định (không để màn trống).
    func test_coCauMacDinh() {
        for k in ["napXuGhiChu", "xoaTaiKhoanMoTa", "hangGhiChu", "hopQuaTaiTro", "chucMungCamOn"] {
            XCTAssertFalse(NoiDung.text(k).isEmpty, k)
        }
        XCTAssertTrue(NoiDung.hopQuaTaiTro.contains("Apple"))
        XCTAssertEqual(NoiDung.text("khongCo"), "")
    }
}
