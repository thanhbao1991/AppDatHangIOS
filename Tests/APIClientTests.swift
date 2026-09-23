import XCTest
@testable import AppDatHangIOS

final class APIClientTests: XCTestCase {
    func testThanhToanQrUrlUsesApiBase() {
        let url = Prefs.thanhToanQrUrl(hoaDonId: "HD1234abcd")
        XCTAssertEqual(url?.absoluteString, "https://api.denncoffee.uk/api/HoaDon/HD1234abcd/qr")
    }

    func testDecodeEnvelope() throws {
        let json = """
        {"isSuccess":true,"message":"ok","data":{"maGioiThieu":"ABC123","soNguoiDaGioiThieu":3,"daDuocGioiThieu":false}}
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(ApiEnvelope<GioiThieuInfo>.self, from: json)
        XCTAssertTrue(env.isSuccess)
        XCTAssertEqual(env.data?.soNguoiDaGioiThieu, 3)
    }
}
