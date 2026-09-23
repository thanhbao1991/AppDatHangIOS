import XCTest
@testable import AppDatHangIOS

final class APIClientTests: XCTestCase {
    func testThanhToanQrUrlUsesApiBase() {
        let url = Prefs.thanhToanQrUrl(hoaDonId: "HD1234abcd")
        XCTAssertEqual(url?.absoluteString, "https://api.denncoffee.uk/api/HoaDon/HD1234abcd/qr")
    }

    func testDecodeEnvelope() throws {
        let json = """
        {"isSuccess":true,"message":"ok","data":{"soLuotConLai":3}}
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(ApiEnvelope<VongQuayInfo>.self, from: json)
        XCTAssertTrue(env.isSuccess)
        XCTAssertEqual(env.data?.soLuotConLai, 3)
    }
}
