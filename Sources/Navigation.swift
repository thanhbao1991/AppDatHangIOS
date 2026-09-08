import Foundation

/// Route cho từng tab — thay cho react-navigation stack (HomeStack/DonHangStack/SettingsStack) bên
/// bản RN cũ. Mỗi tab giữ 1 mảng route riêng, push bằng path.append(...).
enum HomeRoute: Hashable {
    case lyBiMat
    case thanhToan(hoaDonId: String)
}

enum DonHangRoute: Hashable {
    case detail(DonHangKhach)
    case thanhToan(hoaDonId: String)
}

enum SettingsRoute: Hashable {
    case uuDai
}

enum AppTab: Hashable {
    case home, cart, donHang, thongBao, settings
}
