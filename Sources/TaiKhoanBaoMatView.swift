import SwiftUI

/// Menu bảo mật/tài khoản — mở qua icon bánh răng ở MainTabView (chỉ hiện khi đang ở tab Tài
/// khoản). Mỗi thao tác (đổi mật khẩu, thiết bị đăng nhập, xoá tài khoản) tách thành màn riêng,
/// chỉ mở khi khách chủ động bấm vào, thay vì hiện sẵn hết trong 1 danh sách dài.
/// Thiết kế lại 09/11/2026 theo bộ khung TK (TaiKhoanUI.swift): thẻ trắng bo góc, ô icon màu, Đăng xuất là nút viền đỏ,
/// Xoá tài khoản là dòng chữ nhạt cuối màn (hành động hiếm, không mời bấm).
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
            ScrollView {
                VStack(spacing: TK.khoangCach) {
                    VStack(spacing: 0) {
                        NavigationLink { DoiMatKhauView() } label: {
                            TKDong(icon: "key.fill", mau: .orange, tieuDe: "Đổi mật khẩu")
                        }
                        TKKe()
                        NavigationLink { ThietBiDangNhapView() } label: {
                            TKDong(icon: "iphone", mau: .blue, tieuDe: "Thiết bị đăng nhập")
                        }
                    }
                    .buttonStyle(.plain)
                    .tkThe(dem: 12)

                    VStack(spacing: 0) {
                        NavigationLink { TheLeXuView() } label: {
                            TKDong(icon: "doc.text.fill", mau: .orange, tieuDe: "Thể lệ Xu")
                        }
                        TKKe()
                        NavigationLink { ChinhSachBaoMatView() } label: {
                            TKDong(icon: "hand.raised.fill", mau: .green, tieuDe: "Chính sách bảo mật")
                        }
                    }
                    .buttonStyle(.plain)
                    .tkThe(dem: 12)

                    Button { Task { await logout() } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 15, weight: .semibold))
                            Text("Đăng xuất").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(Theme.danger)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: TK.bo, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        )
                        .overlay(RoundedRectangle(cornerRadius: TK.bo, style: .continuous).stroke(Theme.danger.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)

                    NavigationLink { XoaTaiKhoanView(isLoggedIn: $isLoggedIn) } label: {
                        Text("Xoá tài khoản").font(.system(size: 13)).foregroundColor(Theme.textFaint).underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .tkManHinh()
            }
            .background(Theme.bg)
        }
    }

    private func logout() async {
        await APIClient.shared.logout()
        isLoggedIn = false
    }
}
