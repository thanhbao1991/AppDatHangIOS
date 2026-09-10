import Foundation
import UIKit

/// Port 1:1 từ src/api.ts (bản RN cũ) — actor thay cho các biến module-level + Promise coalescing
/// trong JS. Bearer token tự đính kèm, tự refresh 1 lần khi gặp 401 rồi retry đúng request gốc.
actor APIClient {
    static let shared = APIClient()

    private let catalogTTL: TimeInterval = 5 * 60
    private var catalogCache: [String: (at: Date, envelope: Any)] = [:]

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
        Prefs.saveSession(token: token, refreshToken: rt, tenKhachHang: ten)
        return token
    }

    private func deviceName() -> String { UIDevice.current.name }

    /// Envelope chuẩn — mọi lỗi mạng/HTTP đều gói lại thành cùng shape để UI chỉ cần đọc 1 chỗ,
    /// khớp hành vi request() bên bản RN cũ (không throw ra ngoài).
    private func decode<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, authorized: Bool = true) async -> ApiEnvelope<T> {
        let req = makeRequest(path, method: method, body: body, authorized: authorized)
        let (data, status) = await send(req)

        if status == 401 {
            return ApiEnvelope(isSuccess: false, message: "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.", data: nil, warnings: nil)
        }
        if let data, let env = try? JSONDecoder().decode(ApiEnvelope<T>.self, from: data) {
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
            Prefs.saveSession(token: token, refreshToken: rt, tenKhachHang: ten)
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
            Prefs.saveSession(token: token, refreshToken: rt, tenKhachHang: ten)
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

    func xoaTaiKhoan() async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/khachhang-auth/tai-khoan", method: "DELETE")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func doiMatKhau(matKhauCu: String, matKhauMoi: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/khachhang-auth/doi-mat-khau", method: "PUT", body: jsonBody(DoiMatKhauRequest(matKhauCu: matKhauCu, matKhauMoi: matKhauMoi)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    // ===== Catalog (cache 5 phút) =====

    private func cachedDecode<T: Decodable>(_ path: String) async -> ApiEnvelope<T> {
        if let hit = catalogCache[path], Date().timeIntervalSince(hit.at) < catalogTTL,
           let env = hit.envelope as? ApiEnvelope<T> {
            return env
        }
        let env: ApiEnvelope<T> = await decode(path)
        if env.isSuccess {
            catalogCache[path] = (Date(), env)
        }
        return env
    }

    func xoaCacheCatalog() { catalogCache.removeAll() }

    func getSanPhamList() async -> [SanPham] {
        let env: ApiEnvelope<[SanPham]> = await cachedDecode("/dat-hang/menu/san-pham")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func getNhomSanPhamList() async -> [NhomSanPham] {
        let env: ApiEnvelope<[NhomSanPham]> = await cachedDecode("/dat-hang/menu/nhom")
        return env.isSuccess ? (env.data ?? []) : []
    }

    func getToppingList() async -> [Topping] {
        let env: ApiEnvelope<[Topping]> = await cachedDecode("/dat-hang/menu/topping")
        return env.isSuccess ? (env.data ?? []) : []
    }

    /// SanPhamId theo tổng số lượng bán ra giảm dần (30 ngày gần nhất) — dùng để xếp "bán chạy"
    /// lên trước trong từng nhóm ở màn Thực đơn.
    func getBanChayIds() async -> [String] {
        let env: ApiEnvelope<[String]> = await cachedDecode("/dat-hang/menu/ban-chay")
        return env.isSuccess ? (env.data ?? []) : []
    }

    // ===== Đặt món =====

    func datMon(items: [DatMonItem], diaChiText: String, ghiChu: String?, soDienThoaiText: String?, deliveryLat: Double?, deliveryLong: Double?, clientOrderId: String?) async -> ApiEnvelope<DatMonResponse> {
        let body = DatMonRequest(items: items, ghiChu: ghiChu, diaChiText: diaChiText, soDienThoaiText: soDienThoaiText, deliveryLat: deliveryLat, deliveryLong: deliveryLong, clientOrderId: clientOrderId)
        return await decode("/dat-hang/dat-mon", method: "POST", body: jsonBody(body))
    }

    func uocTinhShip(lat: Double, long: Double) async -> ApiEnvelope<UocTinhShip> {
        await decode("/dat-hang/uoc-tinh-ship", method: "POST", body: jsonBody(UocTinhShipRequest(lat: lat, long: long)))
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

    func xoaDiaChi(_ id: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/dia-chi/\(id)", method: "DELETE")
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func datDiaChiMacDinh(_ id: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/dia-chi/\(id)/mac-dinh", method: "PATCH")
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

    func getGiaLyBiMat() async -> Double? {
        let env: ApiEnvelope<Double> = await decode("/dat-hang/ly-bi-mat/gia")
        return env.isSuccess ? env.data : nil
    }

    func datLyBiMat(diaChiText: String, ghiChu: String?, clientOrderId: String?) async -> ApiEnvelope<LyBiMatResult> {
        await decode("/dat-hang/ly-bi-mat", method: "POST", body: jsonBody(DatLyBiMatRequest(diaChiText: diaChiText, ghiChu: ghiChu, clientOrderId: clientOrderId)))
    }

    func danhGiaDon(hoaDonId: String, soSao: Int, nhanXet: String?) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/danh-gia", method: "POST", body: jsonBody(DanhGiaDonRequest(hoaDonId: hoaDonId, soSao: soSao, nhanXet: nhanXet)))
        return ActionResult(success: env.isSuccess, message: env.message)
    }

    func getTheTem() async -> TheTem? {
        let env: ApiEnvelope<TheTem> = await decode("/dat-hang/the-tem")
        return env.isSuccess ? env.data : nil
    }

    func doiTem() async -> ApiEnvelope<TheTem> {
        await decode("/dat-hang/the-tem/doi-thuong", method: "POST")
    }

    func getGioiThieu() async -> GioiThieuInfo? {
        let env: ApiEnvelope<GioiThieuInfo> = await decode("/dat-hang/gioi-thieu")
        return env.isSuccess ? env.data : nil
    }

    func apDungMaGioiThieu(_ ma: String) async -> ActionResult {
        let env: ApiEnvelope<Bool> = await decode("/dat-hang/gioi-thieu/ap-dung", method: "POST", body: jsonBody(ApDungMaGioiThieuRequest(maGioiThieu: ma)))
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

    func nhanQuaSinhNhat() async -> ApiEnvelope<Double> {
        await decode("/dat-hang/sinh-nhat/nhan-qua", method: "POST")
    }

    func quayVongQuay() async -> ApiEnvelope<VongQuayResult> {
        await decode("/dat-hang/vong-quay", method: "POST")
    }
}
