import XCTest

/// Đo độ NẶNG khi cuộn cột món tab Thực đơn — so trước/sau khi đổi cột món từ ScrollView + VStack sang UICollectionView
/// (19/11/2026). Hai bản vuốt văng y hệt nhau (cùng toạ độ, cùng tốc độ); số đo in ở log CI, dòng "measured [...]":
/// - CPU app dùng trong lúc vuốt (CPU Time / Cycles / Instructions Retired) — ít hơn = mỗi khung hình dư thời gian hơn.
/// - Bộ nhớ đỉnh của app.
/// - Khung hình giật (hitch) nếu simulator đo được — test riêng để hỏng thì không kéo theo số CPU.
/// Simulator chạy trên Mac nên số tuyệt đối không giống iPhone thật — chỉ so TƯƠNG ĐỐI 2 bản trên cùng loại máy CI.
/// Trong khối đo KHÔNG hỏi phần tử nào (mỗi lần hỏi XCUITest bắt app dựng lại cây accessibility, ăn CPU của app).
final class CuonMenuDoGiatUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tren: XCUICoordinate!
    private var duoi: XCUICoordinate!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testDoCpuKhiCuonCotMon() throws {
        try choThucDon()
        let opts = XCTMeasureOptions()
        opts.iterationCount = 5
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: opts) {
            vuotMotLuot()
        }
    }

    func testDoKhungHinhKhiCuonCotMon() throws {
        try choThucDon()
        let opts = XCTMeasureOptions()
        opts.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: opts) {
            vuotMotLuot()
        }
    }

    // MARK: - Tiện ích

    /// Chờ thực đơn hiện, tính sẵn 2 điểm vuốt trong cột món (bên phải cột nhóm), làm nóng 1 lượt (ảnh vào RAM…).
    private func choThucDon() throws {
        let tieuDe = app.staticTexts["tieu-de-menu"]
        XCTAssertTrue(tieuDe.waitForExistence(timeout: 90), "Không tải được thực đơn")
        sleep(8)  // ảnh, dải Best Sellers, banner dịp lễ tải xong — bố cục đứng yên
        let x = app.windows.firstMatch.frame.width * 0.7
        let y0 = tieuDe.frame.maxY  // đỉnh 2 cột
        let goc = app.coordinate(withNormalizedOffset: .zero)
        tren = goc.withOffset(CGVector(dx: x, dy: y0 + 80))
        duoi = goc.withOffset(CGVector(dx: x, dy: y0 + 380))
        vuotMotLuot()
        sleep(2)
    }

    /// 5 lần vuốt văng lên (đi sâu xuống thực đơn) rồi 6 lần vuốt văng xuống (về đầu).
    private func vuotMotLuot() {
        for _ in 0..<5 { vuot(len: true) }
        for _ in 0..<6 { vuot(len: false) }
    }

    private func vuot(len: Bool) {
        (len ? duoi : tren).press(forDuration: 0.05, thenDragTo: len ? tren : duoi, withVelocity: .fast, thenHoldForDuration: 0)
        usleep(700_000)
    }
}
