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
    static var isLoggedIn: Bool { !(token?.isEmpty ?? true) }

    /// Sinh 1 lần, ổn định suốt vòng đời cài đặt app — backend dedupe phiên đăng nhập theo thiết bị
    /// bằng id này (đăng nhập lại cùng máy thu hồi phiên cũ thay vì chồng phiên mới).
    static var thietBiId: String {
        if let existing = defaults.string(forKey: keyThietBiId) { return existing }
        let id = "ios-\(UUID().uuidString)"
        defaults.set(id, forKey: keyThietBiId)
        return id
    }

    static func saveSession(token: String, refreshToken: String, tenKhachHang: String, avatarUrl: String? = nil) {
        Prefs.token = token
        Prefs.refreshToken = refreshToken
        Prefs.tenKhachHang = tenKhachHang
        Prefs.avatarUrl = avatarUrl
    }

    static func clear() {
        token = nil
        refreshToken = nil
        tenKhachHang = nil
        avatarUrl = nil
    }

    /// Trang QR chuyển khoản — [AllowAnonymous], HTML tự vẽ (không phải ảnh thuần), dùng lại nguyên
    /// endpoint đã có sẵn cho SMS soạn sẵn (xem HoaDonController.GetBillQrByHoaDonId).
    static func thanhToanQrUrl(hoaDonId: String) -> URL? {
        URL(string: "\(apiBase)/HoaDon/\(hoaDonId)/qr")
    }
}
