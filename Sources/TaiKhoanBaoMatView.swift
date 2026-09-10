import SwiftUI

/// Menu bảo mật/tài khoản — mở qua icon bánh răng ở MainTabView (chỉ hiện khi đang ở tab Tài
/// khoản). Mỗi thao tác (đổi mật khẩu, thiết bị đăng nhập, xoá tài khoản) tách thành màn riêng,
/// chỉ mở khi khách chủ động bấm vào, thay vì hiện sẵn hết trong 1 danh sách dài.
struct TaiKhoanBaoMatView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Bảo mật & Tài khoản", trailing: AnyView(
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundColor(.white)
                }
            ))
            List {
                Section {
                    NavigationLink { DoiMatKhauView() } label: {
                        Label("Đổi mật khẩu", systemImage: "key.fill")
                    }
                    NavigationLink { ThietBiDangNhapView() } label: {
                        Label("Thiết bị đăng nhập", systemImage: "iphone")
                    }
                }

                Section {
                    Button("Đăng xuất") { Task { await logout() } }
                        .foregroundColor(.white).frame(maxWidth: .infinity)
                        .listRowBackground(Theme.danger)
                }

                Section {
                    NavigationLink { XoaTaiKhoanView(isLoggedIn: $isLoggedIn) } label: {
                        Text("Xoá tài khoản").foregroundColor(Theme.textFaint)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func logout() async {
        await APIClient.shared.logout()
        isLoggedIn = false
    }
}
