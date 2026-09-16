import Combine
import Foundation

/// Nguồn sự thật duy nhất cho hạng khách hàng hiện tại trong phiên — Theme.primary/primaryDark đọc
/// từ đây để đổi màu chủ đạo toàn app theo hạng (Bạc/Vàng/Kim Cương), thay vì đợi khách tự mở tab
/// Tài khoản mới thấy màu mới. Cache vào Prefs.hang để lần mở app kế tiếp lên đúng màu ngay từ
/// UINavigationBarAppearance dựng lúc init() (trước khi kịp gọi API), không bị "chớp" về màu mặc định.
final class KhachHangSession: ObservableObject {
    static let shared = KhachHangSession()

    @Published private(set) var hang: String = Prefs.hang ?? "Thành Viên"

    private init() {}

    /// Gọi mỗi khi 1 màn hình fetch được KhachHangVi (MenuView/SettingsView/CheckoutView) — no-op nếu
    /// hạng không đổi, tránh publish thừa gây các View phụ thuộc render lại vô ích mỗi lần polling.
    func capNhatHang(_ hangMoi: String) {
        guard hangMoi != hang else { return }
        hang = hangMoi
        Prefs.hang = hangMoi
        Theme.applyNavBarAppearance()
    }

    /// Gọi lúc đăng xuất — về lại màu mặc định "Thành Viên", tránh khách kế tiếp đăng nhập trên cùng
    /// máy thấy nhầm màu hạng của tài khoản trước.
    func reset() {
        guard hang != "Thành Viên" else { return }
        hang = "Thành Viên"
        Prefs.hang = nil
        Theme.applyNavBarAppearance()
    }
}
