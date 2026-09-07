import SwiftUI

/// Placeholder — Giai đoạn 1 sẽ thay bằng flow SĐT + OTP/mật khẩu thật (port từ LoginScreen.tsx cũ).
struct LoginView: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Đenn Coffee")
                .font(.title.bold())
            Text("Giai đoạn 1 (đăng nhập) chưa làm")
                .foregroundColor(.secondary)
        }
    }
}
