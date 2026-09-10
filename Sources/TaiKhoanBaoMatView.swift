import SwiftUI

/// Gom mọi thao tác bảo mật/tài khoản (đổi mật khẩu, thiết bị đăng nhập, đăng xuất, xoá tài khoản)
/// vào 1 màn riêng, mở qua icon bánh răng ở góc trên-phải (chỉ hiện khi đang ở tab Tài khoản) —
/// tách khỏi SettingsView để danh sách chính (ví, địa chỉ) không lẫn với các nút nhạy cảm/nguy hiểm.
struct TaiKhoanBaoMatView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [PhienDangNhapKhachHang] = []
    @State private var loading = true
    @State private var revokingSession: PhienDangNhapKhachHang?
    @State private var showXoaTaiKhoanConfirm = false
    @State private var xoaTaiKhoanError: String?

    @State private var matKhauCu = ""
    @State private var matKhauMoi = ""
    @State private var matKhauXacNhan = ""
    @State private var dangDoiMatKhau = false
    @State private var doiMatKhauMessage: (isError: Bool, text: String)?

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Bảo mật & Tài khoản", trailing: AnyView(
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundColor(.white)
                }
            ))
            list
        }
        .task { await load() }
        .confirmationDialog("Xoá tài khoản?", isPresented: $showXoaTaiKhoanConfirm, titleVisibility: .visible) {
            Button("Xoá tài khoản", role: .destructive) { Task { await xoaTaiKhoan() } }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn sẽ không thể đăng nhập lại và mất toàn bộ địa chỉ đã lưu. Lịch sử mua hàng vẫn được quán lưu lại. Không thể hoàn tác.")
        }
        .alert("Không xoá được", isPresented: Binding(get: { xoaTaiKhoanError != nil }, set: { if !$0 { xoaTaiKhoanError = nil } })) {
            Button("OK") {}
        } message: {
            Text(xoaTaiKhoanError ?? "")
        }
        .confirmationDialog(revokingSession?.thietBi ?? "Thiết bị không rõ", isPresented: Binding(get: { revokingSession != nil }, set: { if !$0 { revokingSession = nil } }), titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                if let s = revokingSession { Task { await revoke(s) } }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Đăng xuất thiết bị này?")
        }
    }

    private var list: some View {
        List {
            Section("Đổi mật khẩu") {
                SecureField("Mật khẩu hiện tại", text: $matKhauCu)
                SecureField("Mật khẩu mới (tối thiểu 6 ký tự)", text: $matKhauMoi)
                SecureField("Nhập lại mật khẩu mới", text: $matKhauXacNhan)
                if let doiMatKhauMessage {
                    Text(doiMatKhauMessage.text)
                        .font(.system(size: 12))
                        .foregroundColor(doiMatKhauMessage.isError ? Theme.danger : Theme.success)
                }
                Button {
                    Task { await doiMatKhau() }
                } label: {
                    if dangDoiMatKhau { ProgressView() } else { Text("Đổi mật khẩu").fontWeight(.bold) }
                }
                .disabled(dangDoiMatKhau || matKhauCu.isEmpty || matKhauMoi.isEmpty)
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Section("Thiết bị đã đăng nhập") {
                    ForEach(sessions, id: \.id) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.nenTang == "Desktop" ? "desktopcomputer" : "iphone")
                                .foregroundColor(item.laThietBiHienTai ? Theme.success : Theme.primary)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.thietBi ?? "Thiết bị không rõ").font(.system(size: 15, weight: .bold))
                                    if item.laThietBiHienTai {
                                        Text("Thiết bị này").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                            .padding(.horizontal, 7).padding(.vertical, 2).background(Theme.success).clipShape(Capsule())
                                    }
                                }
                                Text(item.nenTang ?? "?").font(.system(size: 12, weight: .bold)).foregroundColor(item.laThietBiHienTai ? Theme.success : Theme.primary)
                                Text("Đăng nhập \(formatUtcShort(item.ngayTao)) · Hết hạn \(formatUtcShort(item.hetHan))")
                                    .font(.system(size: 11)).foregroundColor(Theme.textFaint)
                            }
                            Spacer()
                            if !item.laThietBiHienTai {
                                Button { revokingSession = item } label: {
                                    Image(systemName: "xmark").foregroundColor(Theme.danger)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button("Đăng xuất") { Task { await logout() } }
                    .foregroundColor(.white).frame(maxWidth: .infinity)
                    .listRowBackground(Theme.danger)
            }

            Section {
                Button("Xoá tài khoản") { showXoaTaiKhoanConfirm = true }
                    .foregroundColor(Theme.textFaint).frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Backend trả DateTime "yyyy-MM-ddTHH:mm:ss.fffffff" (Kind=Unspecified nhưng thực chất UTC) —
    /// ép hậu tố "Z" trước khi parse để không bị hiểu nhầm thành giờ máy.
    private func formatUtcShort(_ iso: String) -> String {
        let trimmed = String(iso.prefix(19)) + "Z"
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: trimmed) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "HH:mm dd/MM"
        out.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return out.string(from: date)
    }

    private func load() async {
        sessions = await APIClient.shared.getSessions()
        loading = false
    }

    private func doiMatKhau() async {
        guard matKhauMoi.count >= 6 else {
            doiMatKhauMessage = (true, "Mật khẩu mới phải có ít nhất 6 ký tự.")
            return
        }
        guard matKhauMoi == matKhauXacNhan else {
            doiMatKhauMessage = (true, "Mật khẩu nhập lại không khớp.")
            return
        }
        dangDoiMatKhau = true
        defer { dangDoiMatKhau = false }
        let result = await APIClient.shared.doiMatKhau(matKhauCu: matKhauCu, matKhauMoi: matKhauMoi)
        if result.success {
            matKhauCu = ""; matKhauMoi = ""; matKhauXacNhan = ""
            doiMatKhauMessage = (false, result.message ?? "Đã đổi mật khẩu.")
        } else {
            doiMatKhauMessage = (true, result.message ?? "Đổi mật khẩu thất bại.")
        }
    }

    private func revoke(_ item: PhienDangNhapKhachHang) async {
        let result = await APIClient.shared.revokeSession(item.id)
        if result.success { sessions.removeAll { $0.id == item.id } }
    }

    private func logout() async {
        await APIClient.shared.logout()
        isLoggedIn = false
    }

    private func xoaTaiKhoan() async {
        let result = await APIClient.shared.xoaTaiKhoan()
        if result.success {
            await APIClient.shared.logout()
            isLoggedIn = false
        } else {
            xoaTaiKhoanError = result.message
        }
    }
}
