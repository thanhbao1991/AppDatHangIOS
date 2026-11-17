import XCTest
@testable import AppDatHangIOS

final class NoiDungTests: XCTestCase {
    // Chưa tải được từ backend vẫn phải có câu mặc định (không để màn trống).
    func test_coCauMacDinh() {
        for k in ["napXuGhiChu", "xoaTaiKhoanMoTa", "hangGhiChu", "hopQuaTaiTro", "chucMungHangTieuDe", "chucMungHangPhu", "chucMungTopTieuDe", "chucMungTopPhu",
                  "shipMienPhiGhiChu", "muaHoGiam", "muaHoGiuVoucher", "tangLuotQuaKhiHoanThanh", "napLanDauTieuDe",
                  "voucherKhongApDung", "donTinhHangGiaiThich", "sinhNhatDaNhan",
                  "otpNhapMa", "qrNhacNoiDung", "napXuGiuNoiDung"] {
            XCTAssertFalse(NoiDung.text(k).isEmpty, k)
        }
        // 17/11/2026 (app gọn gàng): cố ý để trống → màn ẩn dòng đó.
        for k in ["napLanDauMoTa", "otpGhiChu", "napXuBannerPhu"] {
            XCTAssertEqual(NoiDung.text(k), "", k)
        }
        XCTAssertTrue(NoiDung.hopQuaTaiTro.contains("Apple"))
        XCTAssertEqual(NoiDung.text("khongCo"), "")
        // {noiDung} để app thay mã nạp riêng của khách
        XCTAssertTrue(NoiDung.text("napXuGiuNoiDung").contains("{noiDung}"))
    }
}
