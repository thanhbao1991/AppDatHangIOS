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
        XCTAssertEqual(ca2[1].tieuDe, "Top 2 người dùng\ntháng 10")
        XCTAssertEqual(ca2[1].soXu, 20000)
        XCTAssertEqual(ChucMungHang.quaCho(try vi(hangDaNhan: true, topDaNhan: false)).map(\.loai), [.top])
        // Backend cũ không gửi daNhan (đã tự cộng) → không hiện
        XCTAssertTrue(ChucMungHang.quaCho(try vi(hangDaNhan: nil, topDaNhan: nil)).isEmpty)
        XCTAssertTrue(ChucMungHang.quaCho(nil).isEmpty)
    }

    // Điểm quầy đã đổi thành Xu (30/10/2026): hiện 1 lần trước quà hạng, bấm "Tuyệt vời" thì lần sau không hiện nữa.
    func test_quaCho_chuyenDiemQuay_hienMotLan() async throws {
        UserDefaults.standard.removeObject(forKey: "chucMung.chuyenDiem.daXem")
        let json = #"{"soDu":30000,"diemThangNay":0,"diemThangTruoc":0,"duocNhanVoucher":false,"daNhanVoucher":false,"tongNo":0,"tongChiTieuThangNay":0,"hang":"Thành Viên","hangThangTruoc":"","yeuThichSanPhamIds":[],"conLaiDeLenHang":0,"phanTramTienDoLenHang":0,"quaChuyenDiemQuay":{"id":"g1","soXu":30000},"hangDayDu":"Bạc II","capTiepTheo":"Vàng","conLaiDeLenCap":50000,"phanTramTienDoCap":0.8,"thuongXuCapTiepTheo":30000}"#
        let v = try JSONDecoder().decode(KhachHangVi.self, from: Data(json.utf8))
        XCTAssertEqual(v.hangDayDu, "Bạc II")
        let ds = ChucMungHang.quaCho(v)
        XCTAssertEqual(ds.map(\.loai), [.chuyenDiem])
        XCTAssertEqual(ds[0].nutBam, "Tuyệt vời")
        let daDong = await ChucMungHang.nhan(ds[0])
        XCTAssertTrue(daDong)
        XCTAssertTrue(ChucMungHang.quaCho(v).isEmpty)
    }
}
