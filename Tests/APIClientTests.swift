import XCTest
@testable import AppDatHangIOS

final class APIClientTests: XCTestCase {
    // Prefs.thanhToanQrUrl đã bị xoá từ khi màn Thanh toán chuyển sang vẽ QR native qua
    // getBillQrImage/getThanhToanInfo (commit 6451e82) — test cũ tham chiếu hàm không còn tồn tại,
    // làm job "test" CI fail âm thầm trên MỌI commit từ đó tới giờ (job "build" vẫn xanh nên không
    // ai để ý). Thay bằng test giữ nguyên tinh thần cũ: chặn quay lại đúng sự cố đã xảy ra thật
    // (incident_cloudflare_http_baseurl) — base URL http:// bị Cloudflare 301 redirect, HttpClient
    // theo 301 trên POST làm mất body, âm thầm hỏng login/đặt hàng.
    func testApiBaseLuonLaHttps() {
        XCTAssertTrue(Prefs.apiBase.hasPrefix("https://"), "apiBase phải luôn là https:// — http:// từng gây mất body request qua Cloudflare 301 redirect")
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
