import SwiftUI

/// Placeholder — Giai đoạn 2-5 sẽ thêm các tab thật (Menu/Đơn hàng/Ưu đãi/Cài đặt, port từ
/// MainTabs.tsx cũ).
struct MainTabView: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Đã đăng nhập")
            Button("Đăng xuất") {
                Task {
                    await APIClient.shared.logout()
                    isLoggedIn = false
                }
            }
        }
    }
}
