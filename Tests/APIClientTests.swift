import XCTest
@testable import AppDatHangIOS

final class APIClientTests: XCTestCase {
    func testThanhToanQrUrlUsesApiBase() async {
        let url = await APIClient.shared.getThanhToanQrUrl(maHoaDon: "HD1234abcd")
        XCTAssertEqual(url?.absoluteString, "https://api.denncoffee.uk/api/HoaDon/HD1234abcd/qr")
    }

    func testDecodeEnvelope() throws {
        let json = """
        {"isSuccess":true,"message":"ok","data":{"tongDonLifetime":3,"mocThuong":10,"temHienTai":3,"duDieuKienDoiThuong":false,"soLanDaDoiThuong":0}}
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(ApiEnvelope<TheTem>.self, from: json)
        XCTAssertTrue(env.isSuccess)
        XCTAssertEqual(env.data?.temHienTai, 3)
    }
}
