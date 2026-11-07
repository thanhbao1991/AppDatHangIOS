import XCTest
@testable import AppDatHangIOS

/// Icon dịp lễ do server quyết định + giãn cách popup — xem AppIconSwitcher.iconMucTieu.
final class AppIconSwitcherTests: XCTestCase {
    private let bayGio = Date(timeIntervalSince1970: 1_800_000_000)
    private func truoc(_ ngay: Double) -> Date { bayGio.addingTimeInterval(-ngay * 86_400) }

    func testChuaTungDoi_DoiNgay() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maIcon: "NOEL", iconHienTai: nil, lanDoiCuoi: nil, bayGio: bayGio), "AppIcon-NOEL")
    }

    func testServerBaoHetDip_VeIconQuan() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maIcon: nil, iconHienTai: "AppIcon-NOEL", lanDoiCuoi: truoc(20), bayGio: bayGio))
    }

    func testDangDungIcon_KhongDoi() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maIcon: "NOEL", iconHienTai: "AppIcon-NOEL", lanDoiCuoi: truoc(1), bayGio: bayGio), "AppIcon-NOEL")
    }

    func testDoiChuaDu7Ngay_HoanLai() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maIcon: "TETDUONG", iconHienTai: "AppIcon-NOEL", lanDoiCuoi: truoc(6.9), bayGio: bayGio), "AppIcon-NOEL")
    }

    func testDoiDu7Ngay_DoiTiep() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maIcon: "TETDUONG", iconHienTai: "AppIcon-NOEL", lanDoiCuoi: truoc(7), bayGio: bayGio), "AppIcon-TETDUONG")
    }

    func testIconChinhDaDungDip_KhongCanDoi() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maIcon: "NHAGIAO", iconHienTai: nil, lanDoiCuoi: nil, bayGio: bayGio, iconDongGoi: "NHAGIAO"))
    }

    func testIconChinhLaDip_ServerBaoHetDip_DungIconPhuQuan() {
        XCTAssertEqual(AppIconSwitcher.iconMucTieu(maIcon: nil, iconHienTai: nil, lanDoiCuoi: nil, bayGio: bayGio, iconDongGoi: "NHAGIAO"), "AppIcon-QUAN")
    }

    func testDangIconPhuNhungIconChinhDaDungDip_VeIconChinh() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maIcon: "NOEL", iconHienTai: "AppIcon-QUAN", lanDoiCuoi: truoc(30), bayGio: bayGio, iconDongGoi: "NOEL"))
    }

    func testIconChinhQuan_ServerBaoQuan_KhongDoi() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maIcon: nil, iconHienTai: nil, lanDoiCuoi: nil, bayGio: bayGio, iconDongGoi: ""))
    }

    func testMaChuaCoIconTrongBanNay_IconQuan() {
        XCTAssertNil(AppIconSwitcher.iconMucTieu(maIcon: "KHONGCO", iconHienTai: nil, lanDoiCuoi: nil, bayGio: bayGio))
    }
}
