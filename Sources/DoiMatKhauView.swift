import SwiftUI

/// Form đổi mật khẩu — tách khỏi TaiKhoanBaoMatView, chỉ hiện khi khách chủ động bấm vào hàng
/// "Đổi mật khẩu" thay vì luôn hiện sẵn trong danh sách chính.
struct DoiMatKhauView: View {
    @State private var matKhauCu = ""
    @State private var matKhauMoi = ""
    @State private var matKhauXacNhan = ""
    @State private var dangDoiMatKhau = false
    @State private var message: (isError: Bool, text: String)?

    var body: some View {
        Form {
            Section {
                SecureField("Mật khẩu hiện tại", text: $matKhauCu)
                SecureField("Mật khẩu mới (tối thiểu 6 ký tự)", text: $matKhauMoi)
                SecureField("Nhập lại mật khẩu mới", text: $matKhauXacNhan)
            }

            if let message {
                Text(message.text)
                    .font(.system(size: 12))
                    .foregroundColor(message.isError ? Theme.danger : Theme.success)
            }

            Section {
                Button {
                    Task { await doiMatKhau() }
                } label: {
                    if dangDoiMatKhau {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Đổi mật khẩu").fontWeight(.bold).frame(maxWidth: .infinity)
                    }
                }
                .disabled(dangDoiMatKhau || matKhauCu.isEmpty || matKhauMoi.isEmpty)
            }
        }
        .navigationTitle("Đổi mật khẩu")
        .navigationBarTitleDisplayMode(.inline)
        .brandNavBar()
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
