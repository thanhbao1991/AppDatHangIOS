import Foundation

/// Route cho từng tab — thay cho react-navigation stack (HomeStack/DonHangStack/SettingsStack) bên
/// bản RN cũ. Mỗi tab giữ 1 mảng route riêng, push bằng path.append(...).
enum HomeRoute: Hashable {
    case lyBiMat
    /// Trang "Thanh toán" trước khi đặt (địa chỉ + hình thức thanh toán) — bước 2 sau tab Giỏ hàng,
    /// KHÁC với .thanhToan bên dưới (đó là trang QR chuyển khoản SAU khi đơn đã tạo xong).
    case checkout
    case thanhToan(hoaDonId: String)
}

enum DonHangRoute: Hashable {
    case detail(DonHangKhach)
    case thanhToan(hoaDonId: String)
}

enum AppTab: Hashable {
    case home, cart, donHang, sanThuong, voucher, settings
}
