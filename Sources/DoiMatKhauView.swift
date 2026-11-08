import SwiftUI

/// Form đổi mật khẩu — tách khỏi TaiKhoanBaoMatView, chỉ hiện khi khách chủ động bấm vào hàng
/// "Đổi mật khẩu" thay vì luôn hiện sẵn trong danh sách chính. Thiết kế lại 09/11/2026 theo bộ khung TK.
struct DoiMatKhauView: View {
    @State private var matKhauCu = ""
    @State private var matKhauMoi = ""
    @State private var matKhauXacNhan = ""
    @State private var dangDoiMatKhau = false
    @State private var message: (isError: Bool, text: String)?

    var body: some View {
        ScrollView {
            VStack(spacing: TK.khoangCach) {
                VStack(alignment: .leading, spacing: 12) {
                    TKTieuDe(icon: "key.fill", mau: .orange, tieuDe: "Mật khẩu")
                    SecureField("Mật khẩu hiện tại", text: $matKhauCu).tkONhap()
                    SecureField("Mật khẩu mới (tối thiểu 6 ký tự)", text: $matKhauMoi).tkONhap()
                    SecureField("Nhập lại mật khẩu mới", text: $matKhauXacNhan).tkONhap()
                    if let message {
                        Label(message.text, systemImage: message.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(message.isError ? Theme.danger : Theme.success)
                    }
                }
                .tkThe()

                Button {
                    Task { await doiMatKhau() }
                } label: {
                    Group {
                        if dangDoiMatKhau { ProgressView().tint(.white) } else { Text("Đổi mật khẩu").font(.system(size: 16, weight: .bold)) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gradientProminent)
                .disabled(dangDoiMatKhau || matKhauCu.isEmpty || matKhauMoi.isEmpty)
            }
            .tkManHinh()
        }
        .background(Theme.bg)
        .navigationTitle("Đổi mật khẩu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func doiMatKhau() async {
        guard matKhauMoi.count >= 6 else {
            message = (true, "Mật khẩu mới phải có ít nhất 6 ký tự.")
            return
        }
        guard matKhauMoi == matKhauXacNhan else {
            message = (true, "Mật khẩu nhập lại không khớp.")
            return
        }
        dangDoiMatKhau = true
        defer { dangDoiMatKhau = false }
        let result = await APIClient.shared.doiMatKhau(matKhauCu: matKhauCu, matKhauMoi: matKhauMoi)
        if result.success {
            matKhauCu = ""; matKhauMoi = ""; matKhauXacNhan = ""
            message = (false, result.message ?? "Đã đổi mật khẩu.")
        } else {
            message = (true, result.message ?? "Đổi mật khẩu thất bại.")
        }
    }
}
