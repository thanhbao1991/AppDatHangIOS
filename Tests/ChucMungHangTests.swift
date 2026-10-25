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

    func test_chiHienMotLanMoiLanCong() throws {
        let t = ThuongHangThang(id: UUID().uuidString, hang: "Bạc", thangDat: "10/2026", soXu: 10000, conLai: 10000, hetHan: "2026-11-30T00:00:00")
        XCTAssertTrue(ChucMungHang.canHien(t))
        ChucMungHang.danhDauDaXem(t)
        XCTAssertFalse(ChucMungHang.canHien(t))
        XCTAssertFalse(ChucMungHang.canHien(nil))
    }
}
