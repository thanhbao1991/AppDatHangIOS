import SwiftUI

/// Xoá tài khoản — 2 bước xác nhận: nhập lại mật khẩu hiện tại rồi hệ thống gửi thêm mã OTP về SĐT
/// đã đăng ký, tránh trường hợp người khác cầm máy đã đăng nhập sẵn xoá hộ tài khoản. Backend
/// KHÔNG xoá cứng dữ liệu KhachHang (lịch sử mua hàng vẫn giữ) — chỉ gỡ mật khẩu/SĐT/địa chỉ/ngày
/// sinh và thu hồi mọi phiên đăng nhập (xem KhachHangAuthService.XoaTaiKhoanAsync).
struct XoaTaiKhoanView: View {
    @Binding var isLoggedIn: Bool

    @State private var matKhau = ""
    @State private var otp = ""
    @State private var step: Step = .nhapMatKhau
    @State private var dangGuiOtp = false
    @State private var dangXoa = false
    @State private var errorMessage: String?
    @State private var showConfirm = false

    private enum Step { case nhapMatKhau, nhapOtp }

    var body: some View {
        Form {
            Section {
                Text("Xoá tài khoản sẽ chấm dứt quyền đăng nhập vĩnh viễn và xoá ngày sinh đã khai. Bạn sẽ không còn thấy lại đơn hàng, thẻ tích điểm hay địa chỉ đã lưu trong app. Số điện thoại, tên và lịch sử mua hàng vẫn được quán lưu giữ (kế toán, chăm sóc khách hàng ngoài app) — xem Chính sách bảo mật. Không thể hoàn tác.")
                    .font(.system(size: 13)).foregroundColor(Theme.textMuted)
            }

            Section("Xác nhận mật khẩu") {
                SecureField("Mật khẩu hiện tại", text: $matKhau)
                    .disabled(step == .nhapOtp)
            }

            if step == .nhapOtp {
                Section("Mã xác nhận") {
                    TextField("Nhập mã OTP đã gửi về SĐT", text: $otp)
                        .keyboardType(.numberPad)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.system(size: 12)).foregroundColor(Theme.danger)
            }

            Section {
                if step == .nhapMatKhau {
                    Button {
                        Task { await guiOtp() }
                    } label: {
                        if dangGuiOtp { ProgressView().frame(maxWidth: .infinity) } else { Text("Gửi mã xác nhận").frame(maxWidth: .infinity) }
                    }
                    .disabled(dangGuiOtp || matKhau.isEmpty)
                } else {
                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        if dangXoa { ProgressView().frame(maxWidth: .infinity) } else { Text("Xoá tài khoản").frame(maxWidth: .infinity) }
                    }
                    .disabled(dangXoa || otp.isEmpty)
                }
            }
        }
        .navigationTitle("Xoá tài khoản")
        .navigationBarTitleDisplayMode(.inline)
        .brandNavBar()
        .confirmationDialog("Xoá tài khoản?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Xoá tài khoản", role: .destructive) { Task { await xoaTaiKhoan() } }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn sẽ không thể đăng nhập lại. Không thể hoàn tác.")
        }
    }

    private func guiOtp() async {
        dangGuiOtp = true
        defer { dangGuiOtp = false }
        errorMessage = nil
        let result = await APIClient.shared.guiOtpXoaTaiKhoan(matKhau: matKhau)
        if result.success {
            step = .nhapOtp
        } else {
            errorMessage = result.message ?? "Không gửi được mã xác nhận."
        }
    }

    private func xoaTaiKhoan() async {
        dangXoa = true
        defer { dangXoa = false }
        let result = await APIClient.shared.xoaTaiKhoan(matKhau: matKhau, otp: otp)
        if result.success {
            await APIClient.shared.logout()
            isLoggedIn = false
        } else {
            errorMessage = result.message
        }
    }
}
