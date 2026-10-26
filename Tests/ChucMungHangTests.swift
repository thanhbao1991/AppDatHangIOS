import XCTest
@testable import AppDatHangIOS

final class ChucMungHangTests: XCTestCase {
    func test_giaiMaThuongHangThang_vaDinhDang() throws {
        let json = #"{"id":"abc","hang":"Vàng","thangDat":"10/2026","soXu":30000,"conLai":20000,"hetHan":"2026-11-30T00:00:00"}"#
        let t = try JSONDecoder().decode(ThuongHangThang.self, from: Data(json.utf8))
        XCTAssertEqual(t.hang, "Vàng")
        XCTAssertEqual(ChucMungHang.ngayHetHan(t.hetHan), "30/11")
        XCTAssertEqual(ChucMungHang.tenThang(t.thangDat), "tháng 10")
    }

    private func vi(hangDaNhan: Bool?, topDaNhan: Bool?) throws -> KhachHangVi {
        var hang = #""thuongHangThang":{"id":"00000000-0000-0000-0000-000000000000","hang":"Bạc","thangDat":"10/2026","soXu":10000,"conLai":10000,"hetHan":"2026-11-30T00:00:00""#
        hang += hangDaNhan.map { #","daNhan":\#($0)}"# } ?? "}"
        var top = #""thuongTopShipper":{"viTri":2,"thangDat":"10/2026","soXu":20000"#
        top += topDaNhan.map { #","daNhan":\#($0)}"# } ?? "}"
        let json = #"{"soDu":0,"diemThangNay":0,"diemThangTruoc":0,"duocNhanVoucher":false,"daNhanVoucher":false,"tongNo":0,"tongChiTieuThangNay":0,"hang":"Thành Viên","hangThangTruoc":"","yeuThichSanPhamIds":[],"conLaiDeLenHang":0,"phanTramTienDoLenHang":0,"#
            + hang + "," + top + "}"
        return try JSONDecoder().decode(KhachHangVi.self, from: Data(json.utf8))
    }

    // Quà chờ nhận hiện tới khi bấm "Nhận ngay"; hạng trước, Top sau, mỗi quà 1 màn.
    func test_quaCho_chiQuaChuaNhan_hangTruocTopSau() throws {
        let ca2 = ChucMungHang.quaCho(try vi(hangDaNhan: false, topDaNhan: false))
        XCTAssertEqual(ca2.map(\.loai), [.hang, .top])
        XCTAssertEqual(ca2[1].tieuDe, "Top 2 shipper\ntháng 10")
        XCTAssertEqual(ca2[1].soXu, 20000)
        XCTAssertEqual(ChucMungHang.quaCho(try vi(hangDaNhan: true, topDaNhan: false)).map(\.loai), [.top])
        // Backend cũ không gửi daNhan (đã tự cộng) → không hiện
        XCTAssertTrue(ChucMungHang.quaCho(try vi(hangDaNhan: nil, topDaNhan: nil)).isEmpty)
        XCTAssertTrue(ChucMungHang.quaCho(nil).isEmpty)
    }
}
