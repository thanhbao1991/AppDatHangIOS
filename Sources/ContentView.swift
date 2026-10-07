import SwiftUI

/// Giai đoạn 0 (khung dự án): route đăng nhập/đã đăng nhập đã nối APIClient thật, nhưng UI hai bên
/// vẫn là placeholder — LoginView/MainTabView thật sẽ thay vào ở Giai đoạn 1-5 (xem project memory
/// nếu tìm bối cảnh: kế hoạch chuyển AppDatHangIOS từ React Native sang native SwiftUI).
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn
    @State private var batBuocCapNhat: AppVersionPolicy?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Apple 5.1.1(v): khách chưa đăng nhập vẫn xem được thực đơn/giỏ hàng — chỉ bắt đăng nhập ở
        // tính năng gắn với tài khoản (đặt hàng, đơn hàng, voucher, ưu đãi, tài khoản), xem MainTabView.
        MainTabView(isLoggedIn: $isLoggedIn)
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
        // Cổng chặn phiên bản tối thiểu, xem VersionGate.swift. Phủ lên TRÊN cùng, không đóng được.
        .overlay {
            if let policy = batBuocCapNhat { ForceUpdateView(policy: policy) }
        }
        .task { await kiemTraPhienBan() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await kiemTraPhienBan() } }
        }
    }

    /// Lỗi mạng/server → fetchPolicy trả nil → giữ nguyên trạng thái hiện tại (fail-open).
    private func kiemTraPhienBan() async {
        guard let policy = await VersionGate.fetchPolicy() else { return }
        batBuocCapNhat = VersionGate.isOutdated(current: VersionGate.currentVersion, minimum: policy.toiThieu) ? policy : nil
    }
}
