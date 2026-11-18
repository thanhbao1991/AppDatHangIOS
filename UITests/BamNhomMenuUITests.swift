import XCTest

/// Bấm nhóm ở cột trái tab Thực đơn phải nhảy ĐÚNG đỉnh nhóm — kể cả nhảy thẳng tới nhóm xa chưa từng hiện.
///
/// Lỗi gốc (17–19/11/2026, chỉ iOS 16–18): cột món là 1 LazyVStack, nhóm chưa vẽ thì iOS ĐOÁN chiều cao → bấm
/// nhóm xa dừng lệch (rơi giữa nhóm khác) hoặc màn trắng. Bấm lần lượt từ trên xuống thì lại đúng (nhóm nào cũng đã
/// vẽ qua) — nên mọi test ở đây đều nhảy cóc NGAY sau khi mở app. Chạy trên simulator iOS 18 ở CI (job `uitest`,
/// dispatch `ui_test=true`); cần mạng thật để tải thực đơn từ api.denncoffee.com (vào thẳng không cần đăng nhập).
final class BamNhomMenuUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        chup("ket-thuc")
    }

    // MARK: - Test

    /// Đúng ca chủ quán báo (XS Max iOS 18.7): mở app bấm thẳng nhóm CUỐI → phải thấy nhóm cuối, không lệch/không trắng.
    func testNhayThangNhomCuoi() throws {
        let ds = try choThucDon()
        let cuoi = ds.ten[ds.ten.count - 1]
        print("SO_NUT_LUC_MO=\(app.buttons.count)")  // đo xem cột món còn lazy không (dựng hết món thì số nút vọt lên)
        XCTAssertFalse(tieuDe(cuoi).exists, "Nhóm cuối đã dựng sẵn lúc mở app — cột món không còn lazy")

        bam(cuoi, ds)
        chup("nhay-thang-\(cuoi)")
        let td = tieuDe(cuoi)
        XCTAssertTrue(td.waitForExistence(timeout: 3), "Bấm #\(cuoi): không thấy tiêu đề nhóm (màn trắng hoặc dừng lệch)")
        let lech = td.frame.minY - dinhCot(ds)
        print("LECH|\(cuoi)|\(lech)")
        // Nhóm cuối có thể ngắn hơn cột → cột dừng ở đáy, tiêu đề nằm thấp hơn đỉnh: chỉ cần trong vùng nhìn thấy.
        XCTAssertGreaterThanOrEqual(lech, -1.5, "Tiêu đề #\(cuoi) bị trôi khỏi đỉnh cột \(lech)pt")
        XCTAssertLessThan(td.frame.maxY, app.windows.firstMatch.frame.maxY - 80, "Tiêu đề #\(cuoi) nằm dưới đáy màn")
        XCTAssertEqual(dangChon(), cuoi)
    }

    /// Nhảy cóc giữa → gần cuối → đầu: mỗi lần tiêu đề nhóm phải nằm ĐÚNG đỉnh cột món (±1,5pt).
    func testNhayCocDungDinhNhom() throws {
        let ds = try choThucDon()
        continueAfterFailure = true  // thấy hết các lần nhảy lệch, không dừng ở lần đầu
        let n = ds.ten.count
        XCTAssertGreaterThanOrEqual(n, 6, "Thực đơn quá ít nhóm để thử nhảy cóc")
        // Bỏ 4 nhóm cuối: nhóm sát đáy có thể không cuộn lên tới đỉnh được (cột dừng ở đáy) — đã có test riêng ở trên.
        var dich: [Int] = []
        for i in [n / 2, n - 5, 1] where i > 0 && i < n - 4 && !dich.contains(i) { dich.append(i) }
        for i in dich {
            let t = ds.ten[i]
            bam(t, ds)
            chup("nhay-coc-\(t)")
            let td = tieuDe(t)
            guard td.waitForExistence(timeout: 3) else {
                XCTFail("Bấm #\(t) (nhóm \(i + 1)/\(n)): không thấy tiêu đề nhóm (màn trắng hoặc dừng lệch)")
                continue
            }
            let lech = td.frame.minY - dinhCot(ds)
            print("LECH|\(t)|\(lech)")
            XCTAssertEqual(lech, 0, accuracy: 1.5, "Bấm #\(t) (nhóm \(i + 1)/\(n)) lệch \(lech)pt so với đỉnh cột")
            XCTAssertEqual(dangChon(), t)
        }
    }

    /// Khách tự cuộn cột món (không bấm cột trái) thì cột trái phải chọn theo nhóm đang xem. Khung nhóm là VStack thường
    /// (19/11) — nếu header không còn lazy thì .onAppear chạy hết lúc mở → cột trái nhảy ngay xuống nhóm cuối.
    func testCuonTayCotTraiChonTheo() throws {
        let ds = try choThucDon()
        guard let dau = dangChon(), let iDau = ds.ten.firstIndex(of: dau) else {
            return XCTFail("Mới mở app không có nhóm nào đang chọn")
        }
        XCTAssertLessThan(iDau, ds.ten.count / 2, "Mới mở app đã chọn #\(dau) (nhóm \(iDau + 1)/\(ds.ten.count))")

        for _ in 0..<5 { keoCotMon(len: true) }
        sleep(1)
        chup("cuon-tay")
        guard let sau = dangChon(), let iSau = ds.ten.firstIndex(of: sau) else {
            return XCTFail("Cuộn tay xong không có nhóm nào đang chọn")
        }
        XCTAssertGreaterThan(iSau, iDau, "Cuộn tay xuống mà cột trái vẫn ở #\(dau)")
    }

    // MARK: - Tiện ích

    private struct ThucDon {
        /// Tên nhóm theo thứ tự cột trái.
        let ten: [String]
        /// Từ đáy tiêu đề "Menu 2026" tới chữ tiêu đề nhóm khi nhóm nằm sát đỉnh cột món (đo lúc vừa mở, cột ở đầu).
        let lechDau: CGFloat
    }

    private var tieuDeMenu: XCUIElement { app.staticTexts["tieu-de-menu"] }
    private var cacNutNhom: XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'nhom|'")) }
    private func nutNhom(_ ten: String) -> XCUIElement { app.buttons["nhom|\(ten)"] }
    private func tieuDe(_ ten: String) -> XCUIElement { app.staticTexts["header|\(ten)"] }
    private func tenNhom(_ e: XCUIElement) -> String { String(e.identifier.dropFirst("nhom|".count)) }

    /// Vị trí chữ tiêu đề nhóm khi nhóm nằm sát đỉnh cột món. Tính lại từ tiêu đề "Menu 2026" mỗi lần (banner dịp lễ
    /// tải sau có thể đẩy cả cột xuống).
    private func dinhCot(_ ds: ThucDon) -> CGFloat { tieuDeMenu.frame.maxY + ds.lechDau }

    /// Chờ thực đơn hiện + bố cục đứng yên, gom tên nhóm (cột trái cũng lazy nên kéo dần xuống), rồi đưa cột trái về đầu.
    private func choThucDon() throws -> ThucDon {
        XCTAssertTrue(tieuDeMenu.waitForExistence(timeout: 90), "Không tải được thực đơn")
        XCTAssertTrue(cacNutNhom.firstMatch.waitForExistence(timeout: 30), "Cột trái không có nhóm nào")
        var truoc: CGFloat = -1
        for _ in 0..<20 {
            sleep(1)
            let y = tieuDeMenu.frame.maxY
            if y == truoc { break }
            truoc = y
        }

        var ten: [String] = []
        for _ in 0..<15 {
            var them = false
            for t in cacNutNhom.allElementsBoundByIndex.map(tenNhom) where !ten.contains(t) {
                ten.append(t)
                them = true
            }
            if !them { break }
            keoCotTrai(len: true)
        }
        print("NHOM|\(ten.joined(separator: "|"))")
        XCTAssertGreaterThanOrEqual(ten.count, 2, "Thực đơn chỉ có \(ten.count) nhóm")
        let nutDau = nutNhom(ten[0])
        for _ in 0..<15 where !(nutDau.exists && nutDau.isHittable) { keoCotTrai(len: false) }

        let dau = tieuDe(ten[0])
        XCTAssertTrue(dau.exists, "Không thấy tiêu đề nhóm đầu #\(ten[0]) lúc mở app")
        chup("mo-app")
        return ThucDon(ten: ten, lechDau: dau.frame.minY - tieuDeMenu.frame.maxY)
    }

    /// Đưa nút nhóm vào tầm bấm (kéo cột trái lên/xuống) rồi bấm, chờ cuộn xong.
    private func bam(_ t: String, _ ds: ThucDon) {
        let nut = nutNhom(t)
        let iT = ds.ten.firstIndex(of: t) ?? 0
        for _ in 0..<15 where !(nut.exists && nut.isHittable) {
            let dangHien = cacNutNhom.allElementsBoundByIndex.compactMap { ds.ten.firstIndex(of: tenNhom($0)) }
            keoCotTrai(len: (dangHien.max() ?? 0) < iT)
        }
        XCTAssertTrue(nut.exists && nut.isHittable, "Không bấm được nút #\(t) ở cột trái")
        nut.tap()
        sleep(2)  // animation cuộn ~0,4s + mọi chỉnh lại sau đó
    }

    /// Nhóm đang chọn ở cột trái (nút mang trait selected).
    private func dangChon() -> String? {
        cacNutNhom.allElementsBoundByIndex.first { $0.isSelected }.map(tenNhom)
    }

    /// Kéo chậm (không vuốt văng) cột trái — `len` = kéo ngón lên để xem nhóm phía dưới.
    private func keoCotTrai(len: Bool) {
        keo(x: 44, tu: 160, den: len ? 20 : 300)
    }

    /// Kéo chậm cột món 240pt — `len` = xem món phía dưới.
    private func keoCotMon(len: Bool) {
        keo(x: app.windows.firstMatch.frame.width * 0.7, tu: len ? 300 : 60, den: len ? 60 : 300)
    }

    /// Toạ độ y tính từ đáy tiêu đề "Menu 2026" (đỉnh 2 cột).
    private func keo(x: CGFloat, tu: CGFloat, den: CGFloat) {
        let goc = app.coordinate(withNormalizedOffset: .zero)
        let y0 = tieuDeMenu.frame.maxY
        goc.withOffset(CGVector(dx: x, dy: y0 + tu))
            .press(forDuration: 0.1, thenDragTo: goc.withOffset(CGVector(dx: x, dy: y0 + den)))
        sleep(1)
    }

    private func chup(_ ten: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = ten
        a.lifetime = .keepAlways
        add(a)
    }
}
