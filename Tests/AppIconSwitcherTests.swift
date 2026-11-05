import XCTest
@testable import AppDatHangIOS

/// Lưới an toàn icon dịp lễ — xem AppIconSwitcher.iconMucTieu.
final class AppIconSwitcherTests: XCTestCase {
    func testDaCapNhat_IconChinhDungDip_KhongDoi() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maDangDienRa: "NOEL", maDongGoi: "NOEL", iconHienTai: nil))
    }

    func testToiNgayLeMaChuaCapNhat_DoiSangIconDip() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maDangDienRa: "NOEL", maDongGoi: "", iconHienTai: nil), "AppIcon-NOEL")
    }

    func testHetDip_GiuNguyenIconDangHien() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maDangDienRa: nil, maDongGoi: "", iconHienTai: "AppIcon-TETAL"), "AppIcon-TETAL")
    }

    func testTatVoucher_IconPhu_VeIconChinhLaIconQuan() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maDangDienRa: nil, maDongGoi: "", iconHienTai: "AppIcon-NOEL", maDaTat: ["NOEL"]))
    }

    func testTatVoucher_IconChinhLaIconDip_DoiSangIconQuan() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maDangDienRa: nil, maDongGoi: "NOEL", iconHienTai: nil, maDaTat: ["NOEL"]), "AppIcon-QUAN")
    }

    func testTatVoucherDipKhac_GiuNguyen() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maDangDienRa: nil, maDongGoi: "", iconHienTai: "AppIcon-TETAL", maDaTat: ["NOEL"]), "AppIcon-TETAL")
    }

    func testDaVeIconQuan_KhongDoiNua() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maDangDienRa: nil, maDongGoi: "NOEL", iconHienTai: "AppIcon-QUAN", maDaTat: ["NOEL"]), "AppIcon-QUAN")
    }

    func testDipKhongCoIcon_GiuNguyen() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maDangDienRa: "GIOTO", maDongGoi: "VALENTINE", iconHienTai: nil), nil)
    }
}
