import SwiftUI

/// Xoá tài khoản — 2 bước xác nhận: nhập lại mật khẩu hiện tại rồi hệ thống gửi thêm mã OTP về SĐT
/// đã đăng ký, tránh trường hợp người khác cầm máy đã đăng nhập sẵn xoá hộ tài khoản. Backend
/// KHÔNG xoá cứng KhachHang/SĐT/địa chỉ/lịch sử mua hàng (dữ liệu kinh doanh của quán) — chỉ gỡ mật
/// khẩu + ngày sinh, thu hồi mọi phiên, và ẩn đơn hàng/thẻ tem/địa chỉ cũ khỏi app (xem
/// KhachHangAuthService.XoaTaiKhoanAsync). Khách VẪN đăng ký lại được bằng đúng SĐT qua OTP —
/// "xoá" ở đây là chấm dứt mật khẩu/phiên hiện tại + làm sạch trải nghiệm app, KHÔNG khoá vĩnh viễn
/// SĐT đó khỏi hệ thống (đừng viết copy khẳng định "không đăng nhập lại được" — sai sự thật).
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

    // Thiết kế lại 09/11/2026 theo bộ khung TK (TaiKhoanUI.swift).
    var body: some View {
        ScrollView {
            VStack(spacing: TK.khoangCach) {
                VStack(alignment: .leading, spacing: 10) {
                    TKTieuDe(icon: "exclamationmark.triangle.fill", mau: Theme.danger, tieuDe: "Trước khi xoá")
                    Text(NoiDung.xoaTaiKhoanMoTa)
                        .font(.system(size: 13)).foregroundColor(Theme.textMuted)
                }
                .tkThe()

                VStack(alignment: .leading, spacing: 12) {
                    TKTieuDe(icon: "lock.fill", mau: .orange, tieuDe: "Xác nhận")
                    SecureField("Mật khẩu hiện tại", text: $matKhau)
                        .disabled(step == .nhapOtp)
                        .tkONhap()
                    if step == .nhapOtp {
                        TextField(NoiDung.text("otpNhapMa"), text: $otp)
                            .keyboardType(.numberPad)
                            .tkONhap()
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13)).foregroundColor(Theme.danger)
                    }
                }
                .tkThe()

                if step == .nhapMatKhau {
                    Button {
                        Task { await guiOtp() }
                    } label: {
                        Group { if dangGuiOtp { ProgressView().tint(.white) } else { Text("Gửi mã xác nhận").font(.system(size: 16, weight: .bold)) } }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.gradientProminent)
                    .disabled(dangGuiOtp || matKhau.isEmpty)
                } else {
                    Button {
                        showConfirm = true
                    } label: {
                        Group { if dangXoa { ProgressView().tint(.white) } else { Text("Xoá tài khoản").font(.system(size: 16, weight: .bold)) } }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.gradientProminent(danger: true))
                    .disabled(dangXoa || otp.isEmpty)
                }
            }
            .tkManHinh()
        }
        .background(Theme.bg)
        .navigationTitle("Xoá tài khoản")
        .navigationBarTitleDisplayMode(.inline)
        .popupHost { host in
            host.confirmationDialog("Xoá tài khoản?", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("Xoá tài khoản", role: .destructive) { Task { await xoaTaiKhoan() } }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Mật khẩu và phiên đăng nhập hiện tại sẽ bị xoá vĩnh viễn. Không thể hoàn tác.")
            }
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
