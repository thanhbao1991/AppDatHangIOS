import Foundation
import UIKit

/// Port 1:1 từ src/api.ts (bản RN cũ) — actor thay cho các biến module-level + Promise coalescing
/// trong JS. Bearer token tự đính kèm, tự refresh 1 lần khi gặp 401 rồi retry đúng request gốc.
actor APIClient {
    static let shared = APIClient()

    private let catalogTTL: TimeInterval = 5 * 60
    private var catalogCache: [String: (at: Date, envelope: Any)] = [:]
    // Gộp các lần gọi TRÙNG endpoint bắn gần như cùng lúc (vd tab Thực đơn và tab Giỏ hàng cùng load
    // menu/san-pham lúc mới mở app, cache 5 phút ở trên chưa kịp có gì) thành 1 network call — cùng ý
    // tưởng với refreshTask bên dưới. Trước đây không có gộp: 2 request trùng cùng bắn đi, cạnh tranh
    // luôn với nhau + với các request khác của cùng tab kia trong giới hạn kết nối đồng thời/host của
    // URLSession, khiến request "tới sau" (thường là tab vừa mở) phải XẾP HÀNG chờ request kia xong
    // mới thực sự chạy — nhìn như tab Giỏ hàng "mờ mãi" tới khi tab Thực đơn tải menu xong.
    private var inFlightCatalog: [String: Task<Any, Never>] = [:]

    private func jsonBody<T: Encodable>(_ obj: T) -> Data {
        try! JSONEncoder().encode(obj)
    }

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil, authorized: Bool = true) -> URLRequest {
        var req = URLRequest(url: URL(string: Prefs.apiBase + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token = Prefs.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        req.timeoutInterval = 15
        return req
    }

    // Gộp các refresh song song thành 1 network call — xem giải thích chi tiết trong api.ts cũ
    // (incident_multiclient_refresh_token_race_2026_09): nhiều màn hình bắn request song song lúc
    // mount, nếu mỗi request tự refresh riêng thì request thắng race lưu token mới, các request thua
    // bị BE từ chối refresh token cũ (đã tiêu) → xoá sạch luôn token mới vừa refresh thành công.
    private var refreshTask: Task<String?, Never>?

    private func send(_ req: URLRequest, allowRefresh: Bool = true) async -> (data: Data?, status: Int) {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401, allowRefresh, req.value(forHTTPHeaderField: "Authorization") != nil {
                let usedToken = req.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
                if let newToken = await refreshTokenCoalesced(previousToken: usedToken) {
                    var retried = req
                    retried.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    return await send(retried, allowRefresh: false)
                }
                Prefs.clear()
                catalogCache.removeAll()
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                return (nil, 401)
            }
            return (data, status)
        } catch {
            return (nil, -1)
        }
    }

    private func refreshTokenCoalesced(previousToken: String?) async -> String? {
        if let current = Prefs.token, !current.isEmpty, current != previousToken { return current }
        if let existing = refreshTask { return await existing.value }
        guard let rt = Prefs.refreshToken else { return nil }
        let task = Task<String?, Never> { await self.doRefresh(rt) }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func doRefresh(_ refreshToken: String) async -> String? {
        let req = makeRequest(
            "/khachhang-auth/refresh", method: "POST",
            body: jsonBody(RefreshRequest(refreshToken: refreshToken, thietBi: deviceName(), nenTang: "iOS", thietBiId: Prefs.thietBiId)),
            authorized: false
        )
        let (data, status) = await send(req, allowRefresh: false)
        guard status == 200, let data,
              let env = try? JSONDecoder().decode(ApiEnvelope<KhachHangLoginResponse>.self, from: data),
              env.isSuccess, let resp = env.data,
              let token = resp.token, let rt = resp.refreshToken, let ten = resp.tenKhachHang else { return nil }
        Prefs.saveSession(token: token, refreshToken: rt, tenKhachHang: ten, avatarUrl: resp.avatarUrl)
        return token
    }

    private func deviceName() -> String { UIDevice.current.name }

    /// Envelope chuẩn — mọi lỗi mạng/HTTP đều gói lại thành cùng shape để UI chỉ cần đọc 1 chỗ,
    /// khớp hành vi request() bên bản RN cũ (không throw ra ngoài).
    private func decode<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, authorized: Bool = true, onRawData: ((Data) -> Void)? = nil) async -> ApiEnvelope<T> {
        let req = makeRequest(path, method: method, body: body, authorized: authorized)
        let (data, status) = await send(req)

        if status == 401 {
            return ApiEnvelope(isSuccess: false, message: "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.", data: nil, warnings: nil)
        }
        if let data, let env = try? JSONDecoder().decode(ApiEnvelope<T>.self, from: data) {
            onRawData?(data)
            return env
        }
        if status >= 500 {
            return ApiEnvelope(isSuccess: false, message: "Server đang gặp sự cố, vui lòng thử lại sau ít phút.", data: nil, warnings: nil)
        }
        if status == 429 {
            return ApiEnvelope(isSuccess: false, message: "Bạn thao tác hơi nhanh, vui lòng chờ một chút rồi thử lại.", data: nil, warnings: nil)
        }
        if status == 403 {
            return ApiEnvelope(isSuccess: false, message: "Bạn không có quyền thực hiện thao tác này.", data: nil, warnings: nil)
        }
        if status == -1 {
            return ApiEnvelope(isSuccess: false, message: "Không kết nối được server.", data: nil, warnings: nil)
        }
        return ApiEnvelope(isSuccess: false, message: "Không đọc được phản hồi từ server.", data: nil, warnings: nil)
    }

    // ===== Đăng nhập khách =====

    struct SdtBody: Encodable { let soDienThoai: String }
    func kiemTraSdt(_ soDienThoai: String) async -> ApiEnvelope<Bool> {
        await decode("/khachhang-auth/kiem-tra-sdt", method: "POST", body: jsonBody(SdtBody(soDienThoai: soDienThoai)), authorized: false)
    }

    func dangNhapMatKhau(soDienThoai: String, matKhau: String) async -> ApiEnvelope<KhachHangLoginResponse> {
        let body = LoginRequest(soDienThoai: soDienThoai, matKhau: matKhau, thietBi: deviceName(), nenTang: "iOS", thietBiId: Prefs.thietBiId)
        let result: ApiEnvelope<KhachHangLoginResponse> = await decode("/khachhang-auth/dang-nhap", method: "POST", body: jsonBody(body), authorized: false)
        if result.isSuccess, let d = result.data, let token = d.token, let rt = d.refreshToken, let ten = d.tenKhachHang {
            Prefs.saveSession(token: token, refreshToken: rt, tenKhachHang: ten, avatarUrl: d.avatarUrl)
        }
        return result
    }

    struct OtpResponse: Decodable { let moPhong: Bool?; let otp: String? }
    func guiOtp(_ soDienThoai: String) async -> ApiEnvelope<OtpResponse> {
        await decode("/khachhang-auth/gui-otp", method: "POST", body: jsonBody(SdtBody(soDienThoai: soDienThoai)), authorized: false)
    }

    struct KiemTraOtpBody: Encodable { let soDienThoai: String; let otp: String }
    func kiemTraOtp(soDienThoai: String, otp: String) async -> ApiEnvelope<Bool> {
        await decode("/khachhang-auth/kiem-tra-otp", method: "POST", body: jsonBody(KiemTraOtpBody(soDienThoai: soDienThoai, otp: otp)), authorized: false)
    }

    func xacNhanOtp(soDienThoai: String, otp: String, matKhau: String) async -> ApiEnvelope<KhachHangLoginResponse> {
        let body = OtpConfirmRequest(soDienThoai: soDienThoai, otp: otp, matKhau: matKhau, thietBi: deviceName(), nenTang: "iOS", thietBiId: Prefs.thietBiId)
        let result: ApiEnvelope<KhachHangLoginResponse> = await decode("/khachhang-auth/xac-nhan-otp", method: "POST", body: jsonBody(body), authorized: false)
        if result.isSuccess, let d = result.data, let token = d.token, let rt = d.refreshToken, let ten = d.tenKhachHang {
            Prefs.saveSession(token: token, refreshToken: rt, tenKhachHang: ten, avatarUrl: d.avatarUrl)
        }
        return result
    }

    func logout() async {
        _ = await decode("/khachhang-auth/logout", method: "POST") as ApiEnvelope<Bool>
        Prefs.clear()
        catalogCache.removeAll()
    }

    func getSessions() async -> [PhienDangNhapKhachHang] {
        let env: ApiEnvelope<[PhienDangNhapKhachHang]> = await decode("/khachhang-auth/sessions")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func revokeSession(_ id: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/khachhang-auth/sessions/\(id)", method: "DELETE")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    /// Chưa gọi thật ở đâu cho tới khi có APNs (Apple Developer Program) — giữ sẵn để không phải
    /// sửa kiến trúc khi cắm push vào sau. Field "expoPushToken" giữ nguyên tên JSON backend đang
    /// đọc (KhachHangAuthController) — đổi tên khi backend đổi sang APNs raw token.
    func registerPushToken(_ token: String?) async {
        _ = await decode("/khachhang-auth/push-token", method: "PUT", body: jsonBody(PushTokenRequest(expoPushToken: token))) as ApiEnvelope<Bool>
    }

    /// Xoá tài khoản giờ đòi 2 bước: guiOtpXoaTaiKhoan (xác minh mật khẩu, gửi OTP về SĐT) rồi mới
    /// gọi xoaTaiKhoan(matKhau:otp:) — tránh khách bị người khác cầm máy đã đăng nhập sẵn xoá hộ.
    struct MatKhauBody: Encodable { let matKhau: String }
    func guiOtpXoaTaiKhoan(matKhau: String) async -> ActionResult {
        let env: ApiEnvelope<OtpResponse> = await decode("/khachhang-auth/tai-khoan/gui-otp-xoa", method: "POST", body: jsonBody(MatKhauBody(matKhau: matKhau)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    struct XoaTaiKhoanBody: Encodable { let matKhau: String; let otp: String }
    func xoaTaiKhoan(matKhau: String, otp: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/khachhang-auth/tai-khoan", method: "DELETE", body: jsonBody(XoaTaiKhoanBody(matKhau: matKhau, otp: otp)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func doiMatKhau(matKhauCu: String, matKhauMoi: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/khachhang-auth/doi-mat-khau", method: "PUT", body: jsonBody(DoiMatKhauRequest(matKhauCu: matKhauCu, matKhauMoi: matKhauMoi)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func capNhatTenHienThi(_ tenHienThi: String?) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/khachhang-auth/ten-hien-thi", method: "PUT", body: jsonBody(CapNhatTenHienThiRequest(tenHienThi: tenHienThi)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    /// imageData đã được crop/resize nhẹ ở client (xem UIImage.resizedForMenuUpload) — server chỉ
    /// giới hạn 2MB để chặn client không tuân thủ, không tự resize lại.
    func uploadAvatar(imageData: Data, mimeType: String = "image/jpeg") async -> (url: String?, message: String?) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = makeRequest("/khachhang-auth/avatar", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, _) = await send(req)
        guard let data else { return (nil, "Không có phản hồi từ server.") }
        guard let env = try? JSONDecoder().decode(ApiEnvelope<String>.self, from: data) else {
            return (nil, "Không đọc được phản hồi từ server.")
        }
        return (env.data, env.isSuccess ? nil : (env.message ?? "Cập nhật ảnh thất bại."))
    }

    // ===== Catalog (cache 5 phút RAM + cache đĩa không hạn) =====
    //
    // Cache RAM (catalogCache, 5 phút) mất sạch mỗi lần app bị kill — khách tắt mở lại app trong
    // ngày là coi như cache rỗng, MenuView phải chờ network xong mới hiện được gì (thấy "hơi chậm").
    // Ghi thêm 1 bản xuống đĩa (không hết hạn, chỉ ghi đè khi có bản mới) để lúc cold-start có ngay
    // dữ liệu CŨ hiện tạm trong lúc network thật chạy nền — xem MenuView.load().

    private lazy var diskCacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MenuCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func diskCacheURL(for path: String) -> URL {
        diskCacheDir.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_") + ".json")
    }

    private func loadDiskCache<T: Decodable>(_ path: String) -> ApiEnvelope<T>? {
        guard let data = try? Data(contentsOf: diskCacheURL(for: path)) else { return nil }
        return try? JSONDecoder().decode(ApiEnvelope<T>.self, from: data)
    }

    private func saveDiskCache(_ path: String, data: Data) {
        try? data.write(to: diskCacheURL(for: path), options: .atomic)
    }

    private func cachedDecode<T: Decodable>(_ path: String) async -> ApiEnvelope<T> {
        if let hit = catalogCache[path], Date().timeIntervalSince(hit.at) < catalogTTL,
           let env = hit.envelope as? ApiEnvelope<T> {
            return env
        }
        // Đã có request TRÙNG path đang bay tới server (do 1 lần gọi khác trước đó) — chờ chung kết
        // quả đó thay vì bắn thêm 1 request nữa. await task.value KHÔNG chặn actor (actor được nhả ra
        // ở điểm suspend), nên các path KHÁC vẫn xử lý bình thường song song.
        if let existing = inFlightCatalog[path], let env = await existing.value as? ApiEnvelope<T> {
            return env
        }
        let task = Task<Any, Never> { () -> Any in
            let env: ApiEnvelope<T> = await self.decode(path, onRawData: { raw in self.saveDiskCache(path, data: raw) })
            return env
        }
        inFlightCatalog[path] = task
        let env = await task.value as! ApiEnvelope<T>
        inFlightCatalog[path] = nil
        if env.isSuccess {
            catalogCache[path] = (Date(), env)
        }
        return env
    }

    func xoaCacheCatalog() { catalogCache.removeAll() }

    /// Bản cache đĩa cuối cùng (không quan tâm mới/cũ) — đọc thẳng, không gọi mạng. Dùng để hiện
    /// menu ngay lúc app vừa mở lại (cache RAM rỗng) trong lúc network thật chạy nền, xem MenuView.load().
    struct MenuSnapshot {
        let sanPhams: [SanPham]
        let nhoms: [NhomSanPham]
        let toppings: [Topping]
        let banChayIds: [String]
    }

    func getMenuDiskSnapshot() -> MenuSnapshot? {
        guard let spEnv: ApiEnvelope<[SanPham]> = loadDiskCache("/dat-hang/menu/san-pham"),
              let sp = spEnv.data, !sp.isEmpty else { return nil }
        let nhomEnv: ApiEnvelope<[NhomSanPham]>? = loadDiskCache("/dat-hang/menu/nhom")
        let topEnv: ApiEnvelope<[Topping]>? = loadDiskCache("/dat-hang/menu/topping")
        let banChayEnv: ApiEnvelope<[String]>? = loadDiskCache("/dat-hang/menu/ban-chay")
        return MenuSnapshot(
            sanPhams: sp,
            nhoms: nhomEnv?.data ?? [],
            toppings: topEnv?.data ?? [],
            banChayIds: banChayEnv?.data ?? []
        )
    }

    func getSanPhamList() async -> [SanPham] {
        let env: ApiEnvelope<[SanPham]> = await cachedDecode("/dat-hang/menu/san-pham")
        return env.isSuccess ? (env.data ?? []) : []
    }

    /// Bản có kèm isSuccess/message — getSanPhamList() ở trên nuốt hẳn lỗi thành [] rỗng, không phân
    /// biệt được "thực đơn thật sự trống" với "mất mạng/server lỗi". MenuView cần phân biệt 2 trường
    /// hợp đó để hiện đúng thông báo (xem MenuView.load) — các nơi khác không cần thì cứ dùng bản cũ.
    func getSanPhamListResult() async -> ApiEnvelope<[SanPham]> {
        await cachedDecode("/dat-hang/menu/san-pham")
    }

    func getNhomSanPhamList() async -> [NhomSanPham] {
        let env: ApiEnvelope<[NhomSanPham]> = await cachedDecode("/dat-hang/menu/nhom")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func getToppingList() async -> [Topping] {
        let env: ApiEnvelope<[Topping]> = await cachedDecode("/dat-hang/menu/topping")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func getTenDuongList() async -> [TenDuong] {
        let env: ApiEnvelope<[TenDuong]> = await cachedDecode("/dat-hang/menu/ten-duong")
        return env.isSuccess ? (env.data ?? []) : []
    }

    /// SanPhamId theo tổng số lượng bán ra giảm dần (30 ngày gần nhất) — dùng để xếp "bán chạy"
    /// lên trước trong từng nhóm ở màn Thực đơn.
    func getBanChayIds() async -> [String] {
        let env: ApiEnvelope<[String]> = await cachedDecode("/dat-hang/menu/ban-chay")
        return env.isSuccess ? (env.data ?? []) : []
    }

    // ===== Đặt món =====

    func datMon(items: [DatMonItem], diaChiText: String, ghiChu: String?, soDienThoaiText: String?, deliveryLat: Double?, deliveryLong: Double?, clientOrderId: String?, nhanTaiQuan: Bool = false, dungVi: Bool = false, hinhThucThanhToan: String? = nil, voucherId: String? = nil, laDatLai: Bool = false) async -> ApiEnvelope<DatMonResponse> {
        let body = DatMonRequest(items: items, ghiChu: ghiChu, diaChiText: diaChiText, soDienThoaiText: soDienThoaiText, deliveryLat: deliveryLat, deliveryLong: deliveryLong, clientOrderId: clientOrderId, nhanTaiQuan: nhanTaiQuan, dungVi: dungVi, hinhThucThanhToan: hinhThucThanhToan, voucherId: voucherId, laDatLai: laDatLai)
        return await decode("/dat-hang/dat-mon", method: "POST", body: jsonBody(body))
    }

    /// Voucher khách hiện tại ĐANG đủ điều kiện dùng — không cache (điều kiện đổi ngay sau đơn đầu
    /// tiên, không muốn khách thấy voucher "còn dùng được" đã hết hạn vì cache cũ).
    func getVoucherKhaDung() async -> [Voucher] {
        let env: ApiEnvelope<[Voucher]> = await decode("/dat-hang/voucher/kha-dung")
        return env.isSuccess ? (env.data ?? []) : []
    }

    /// Toàn bộ voucher của tài khoản (kể cả đã dùng) cho tab Ưu đãi.
    func getVoucherCuaToi() async -> [VoucherCuaToi] {
        let env: ApiEnvelope<[VoucherCuaToi]> = await decode("/dat-hang/voucher/cua-toi")
        return env.isSuccess ? (env.data ?? []) : []
    }

    /// SanPhamId khách ĐÃ TỪNG đặt (mọi kênh bán) — CheckoutView dùng để tự kiểm tra voucher
    /// MonMoiTraiNghiem (Voucher.chiApDungKhiCoMonMoi) trước khi cho chọn.
    func getSanPhamDaTungDat() async -> [String] {
        let env: ApiEnvelope<[String]> = await decode("/dat-hang/voucher/san-pham-da-dat")
        return env.isSuccess ? (env.data ?? []) : []
    }

    /// soLuong = tổng số ly (drinks, không tính topping) trong giỏ — bán kính miễn phí ship tính
    /// theo số này từ 2026-09-23 (xem ShippingFeeHelper.TinhPhiShip), tongTienDon giờ chỉ để ghi log.
    func uocTinhShip(lat: Double, long: Double, tongTienDon: Double, soLuong: Int) async -> ApiEnvelope<UocTinhShip> {
        await decode("/dat-hang/uoc-tinh-ship", method: "POST", body: jsonBody(UocTinhShipRequest(lat: lat, long: long, tongTienDon: tongTienDon, soLuong: soLuong)))
    }

    func getDonCuaToi() async -> [DonHangKhach] {
        let env: ApiEnvelope<[DonHangKhach]> = await decode("/dat-hang/don-cua-toi?take=50")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func huyDon(_ id: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/don/\(id)", method: "DELETE")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    // ===== Địa chỉ =====

    func getDiaChiList() async -> [DiaChiKhachHang] {
        let env: ApiEnvelope<[DiaChiKhachHang]> = await decode("/dat-hang/dia-chi")
        return env.isSuccess ? (env.data ?? []) : []
    }

    struct DiaChiBody: Encodable { let diaChi: String }

    func themDiaChi(_ diaChi: String) async -> ActionResult {
        let env: ApiEnvelope<DiaChiKhachHang> = await decode("/dat-hang/dia-chi", method: "POST", body: jsonBody(DiaChiBody(diaChi: diaChi)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func suaDiaChi(_ id: String, diaChi: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/dia-chi/\(id)", method: "PUT", body: jsonBody(DiaChiBody(diaChi: diaChi)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func xoaDiaChi(_ id: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/dia-chi/\(id)", method: "DELETE")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func datDiaChiMacDinh(_ id: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/dia-chi/\(id)/mac-dinh", method: "PATCH")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    // ===== Yêu thích (khách tự chọn qua nút tim ở MenuView) =====

    func themYeuThich(_ sanPhamId: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/yeu-thich/\(sanPhamId)", method: "POST")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func xoaYeuThich(_ sanPhamId: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/yeu-thich/\(sanPhamId)", method: "DELETE")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    // ===== Thông báo =====

    func getThongBao() async -> [ThongBao] {
        let env: ApiEnvelope<[ThongBao]> = await decode("/dat-hang/thong-bao")
        return env.isSuccess ? (env.data ?? []) : []
    }

    // ===== Ví / gamification =====

    func getVi() async -> KhachHangVi? {
        let env: ApiEnvelope<KhachHangVi> = await decode("/dat-hang/vi")
        return env.isSuccess ? env.data : nil
    }

    func getLichSuVi() async -> [ViGiaoDich] {
        let env: ApiEnvelope<[ViGiaoDich]> = await decode("/dat-hang/vi-giao-dich")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func getLichSuCongNo() async -> [CongNoLichSu] {
        let env: ApiEnvelope<[CongNoLichSu]> = await decode("/dat-hang/cong-no-lich-su")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func getGiaLyBiMat() async -> Double? {
        let env: ApiEnvelope<Double> = await decode("/dat-hang/ly-bi-mat/gia")
        return env.isSuccess ? env.data : nil
    }

    /// Giờ mở/đóng cửa quán — dùng để chặn UI đặt hàng ngoài giờ + hiện banner (server vẫn chặn thật
    /// ở DatMonAsync, đây chỉ để tránh khách điền hết giỏ hàng rồi mới báo lỗi lúc bấm Đặt hàng).
    func getGioMoBan() async -> GioMoBanDto? {
        let env: ApiEnvelope<GioMoBanDto> = await decode("/dat-hang/gio-mo-ban")
        return env.isSuccess ? env.data : nil
    }

    func datLyBiMat(diaChiText: String, ghiChu: String?, clientOrderId: String?) async -> ApiEnvelope<LyBiMatResult> {
        await decode("/dat-hang/ly-bi-mat", method: "POST", body: jsonBody(DatLyBiMatRequest(diaChiText: diaChiText, ghiChu: ghiChu, clientOrderId: clientOrderId)))
    }

    func danhGiaDon(hoaDonId: String, soSao: Int, nhanXet: String?) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/danh-gia", method: "POST", body: jsonBody(DanhGiaDonRequest(hoaDonId: hoaDonId, soSao: soSao, nhanXet: nhanXet)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func getSinhNhat() async -> SinhNhatInfo? {
        let env: ApiEnvelope<SinhNhatInfo> = await decode("/dat-hang/sinh-nhat")
        return env.isSuccess ? env.data : nil
    }

    func capNhatNgaySinh(_ ngaySinh: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/sinh-nhat", method: "PUT", body: jsonBody(CapNhatNgaySinhRequest(ngaySinh: ngaySinh)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    /// Đổi 2026-09-23: không còn thưởng Xu trực tiếp — quà sinh nhật giờ tặng +1 lượt quay may mắn.
    func nhanQuaSinhNhat() async -> ApiEnvelope<Bool> {
        await decode("/dat-hang/sinh-nhat/nhan-qua", method: "POST")
    }

    func quayVongQuay() async -> ApiEnvelope<VongQuayResult> {
        await decode("/dat-hang/vong-quay", method: "POST")
    }

    /// Lượt còn lại hôm nay (miễn phí + thưởng) — gọi lúc mở tab Ưu đãi.
    func getVongQuayInfo() async -> VongQuayInfo? {
        let env: ApiEnvelope<VongQuayInfo> = await decode("/dat-hang/vong-quay/thong-tin")
        return env.isSuccess ? env.data : nil
    }

    /// Danh sách ô thưởng để vẽ bánh xe quay thật — gọi 1 lần lúc load tab, không đổi giữa các lần.
    func getVongQuayMoTa() async -> [VongQuayMoTaItem]? {
        let env: ApiEnvelope<[VongQuayMoTaItem]> = await decode("/dat-hang/vong-quay/mo-ta")
        return env.isSuccess ? env.data : nil
    }

    func getDiemDanhInfo() async -> DiemDanhInfo? {
        let env: ApiEnvelope<DiemDanhInfo> = await decode("/dat-hang/diem-danh")
        return env.isSuccess ? env.data : nil
    }

    func diemDanh() async -> ApiEnvelope<DiemDanhResult> {
        await decode("/dat-hang/diem-danh", method: "POST")
    }
}
