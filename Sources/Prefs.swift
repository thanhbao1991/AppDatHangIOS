import Foundation
import Security

// Bắn khi APIClient phát hiện refresh token bị thu hồi/hết hạn thật (không tự cứu được nữa) —
// ContentView lắng nghe để đưa app quay lại LoginView.
extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

/// Host app THẬT được khởi động khi chạy unit test — xem giải thích chi tiết ở Prefs.swift của
/// AppQuanLyIOS. Dùng để tắt hành vi tự động (network thật, ghi Prefs) khi chạy dưới XCTest.
enum RuntimeEnv {
    static let isRunningUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

/// Wrapper Keychain tối giản — port trực tiếp lý do bản RN dùng expo-secure-store thay AsyncStorage
/// cho token: Keychain mã hoá, không đọc được kể cả máy jailbreak/backup, khác UserDefaults là
/// plist plaintext. Chỉ token/refreshToken đi qua đây; dữ liệu không nhạy cảm (tên khách, thietBiId)
/// vẫn dùng UserDefaults như AppQuanLyIOS.
private enum Keychain {
    // CI build không code-sign (CODE_SIGNING_ALLOWED=NO) → SecItemAdd thất bại vì thiếu entitlement
    // Keychain, âm thầm không lưu được gì (SecItemAdd trả lỗi nhưng Keychain.set() không throw ra
    // ngoài) — PrefsTests round-trip đọc lại ra nil dù vừa "lưu" xong. Dùng in-memory store khi chạy
    // dưới XCTest để test được đúng LOGIC round-trip, không phải hạ tầng Keychain của hệ điều hành
    // (Keychain thật chỉ hoạt động đáng tin cậy trên build đã ký, tức app cài thật trên máy).
    private static var memoryStore: [String: String] = [:]

    static func set(_ value: String?, key: String) {
        if RuntimeEnv.isRunningUnitTests {
            memoryStore[key] = value
            return
        }
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        if RuntimeEnv.isRunningUnitTests { return memoryStore[key] }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum Prefs {
    static let apiBase = "https://api.denncoffee.uk/api"

    private static let defaults = UserDefaults.standard
    private static let keyToken = "token"
    private static let keyRefreshToken = "refresh_token"
    private static let keyTenKhachHang = "ten_khach_hang"
    private static let keyAvatarUrl = "avatar_url"
    private static let keyThietBiId = "thiet_bi_id"
    /// Cache hạng lần fetch KhachHangVi gần nhất — chỉ để KhachHangSession lên màu đúng NGAY lúc app
    /// khởi động (trước khi kịp gọi API), không phải nguồn sự thật (nguồn thật luôn là API).
    private static let keyHang = "hang_khach_hang"
    private static let keyHinhThucThanhToan = "hinh_thuc_thanh_toan"
    private static let keyKhachHangId = "khach_hang_id"

    static var token: String? {
        get { Keychain.get(keyToken) }
        set { Keychain.set(newValue, key: keyToken) }
    }
    static var refreshToken: String? {
        get { Keychain.get(keyRefreshToken) }
        set { Keychain.set(newValue, key: keyRefreshToken) }
    }
    static var tenKhachHang: String? {
        get { defaults.string(forKey: keyTenKhachHang) }
        set { defaults.set(newValue, forKey: keyTenKhachHang) }
    }
    static var avatarUrl: String? {
        get { defaults.string(forKey: keyAvatarUrl) }
        set { defaults.set(newValue, forKey: keyAvatarUrl) }
    }
    /// Id khách đang đăng nhập — CHỈ dùng để tách khoá "đã xem thông báo" theo từng tài khoản (xem
    /// thongBaoLastSeen bên dưới), không phải nguồn sự thật cho gì khác (API luôn tự suy ra từ JWT).
    static var khachHangId: String? {
        get { defaults.string(forKey: keyKhachHangId) }
        set { defaults.set(newValue, forKey: keyKhachHangId) }
    }
    static var isLoggedIn: Bool { !(token?.isEmpty ?? true) }
    static var hang: String? {
        get { defaults.string(forKey: keyHang) }
        set { defaults.set(newValue, forKey: keyHang) }
    }

    /// Hình thức thanh toán khách chọn lần đặt hàng GẦN NHẤT (rawValue của HinhThucThanhToan, xem
    /// CheckoutView.swift) — nhớ lại để lần sau tự chọn sẵn, khỏi bắt khách chọn lại mỗi đơn. nil =
    /// chưa từng đặt lần nào, CheckoutView tự coi là COD (mặc định).
    static var hinhThucThanhToan: String? {
        get { defaults.string(forKey: keyHinhThucThanhToan) }
        set { defaults.set(newValue, forKey: keyHinhThucThanhToan) }
    }

    /// Sinh 1 lần, ổn định suốt vòng đời cài đặt app — backend dedupe phiên đăng nhập theo thiết bị
    /// bằng id này (đăng nhập lại cùng máy thu hồi phiên cũ thay vì chồng phiên mới).
    static var thietBiId: String {
        if let existing = defaults.string(forKey: keyThietBiId) { return existing }
        let id = "ios-\(UUID().uuidString)"
        defaults.set(id, forKey: keyThietBiId)
        return id
    }

    /// Mốc "đã xem thông báo" gần nhất — TÁCH RIÊNG theo khachHangId (feedback 2026-09-29: "login
    /// vào lúc nào badge cũng 50"). Trước đây dùng 1 key CHUNG CẢ MÁY rồi bị XOÁ mỗi lần đăng xuất
    /// (fix 2026-09-14 cho bug đổi tài khoản khác trên cùng máy vẫn thấy mốc cũ) — nhưng đăng
    /// xuất/đăng nhập LẠI CHÍNH tài khoản đó (ví dụ cài lại app, refresh token hết hạn) cũng bị coi
    /// là "đổi tài khoản", xoá sạch mốc, khiến TOÀN BỘ lịch sử (tối đa 50 tin, xem
    /// ThongBaoService.Take(50)) hiện lại thành "chưa đọc" mỗi lần đăng nhập. Giờ khoá theo
    /// khachHangId — mỗi tài khoản có mốc RIÊNG, không đụng nhau (giữ đúng ý fix cũ) NHƯNG không bị
    /// xoá khi đăng xuất/đăng nhập lại CHÍNH tài khoản đó nữa.
    static var thongBaoLastSeen: String? {
        get { defaults.string(forKey: "thongBaoLastSeen_\(khachHangId ?? "anon")") }
        set { defaults.set(newValue, forKey: "thongBaoLastSeen_\(khachHangId ?? "anon")") }
    }

    static func saveSession(token: String, refreshToken: String, khachHangId: String? = nil, tenKhachHang: String, avatarUrl: String? = nil) {
        Prefs.token = token
        Prefs.refreshToken = refreshToken
        if let khachHangId { Prefs.khachHangId = khachHangId }
        Prefs.tenKhachHang = tenKhachHang
        Prefs.avatarUrl = avatarUrl
    }

    static func clear() {
        token = nil
        refreshToken = nil
        tenKhachHang = nil
        avatarUrl = nil
        KhachHangSession.shared.reset()
        // KHÔNG xoá khachHangId / thongBaoLastSeen ở đây nữa (đổi 2026-09-29) — thongBaoLastSeen giờ
        // đã khoá riêng theo khachHangId (xem property phía trên) nên tự nhiên không đụng tài khoản
        // khác, và đăng nhập lại CHÍNH tài khoản này (không đổi khachHangId) vẫn giữ đúng mốc đã xem,
        // không còn hiện lại toàn bộ lịch sử thành "chưa đọc" mỗi lần đăng xuất/vào lại.
    }
}
