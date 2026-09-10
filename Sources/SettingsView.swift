import SwiftUI

/// Port từ SettingsScreen.tsx — ví/hạng thành viên, địa chỉ đã lưu, thiết bị đăng nhập, đăng xuất/
/// xoá tài khoản.
struct SettingsView: View {
    @Binding var isLoggedIn: Bool

    @State private var sessions: [PhienDangNhapKhachHang] = []
    @State private var diaChiList: [DiaChiKhachHang] = []
    @State private var vi: KhachHangVi?
    @State private var loading = true
    @State private var showXoaTaiKhoanConfirm = false
    @State private var xoaTaiKhoanError: String?
    @State private var revokingSession: PhienDangNhapKhachHang?

    private let hangColor: [String: Color] = [
        "Kim Cương": Color(red: 0, green: 0.51, blue: 0.56),
        "Vàng": Color(red: 0.72, green: 0.53, blue: 0.04),
        "Bạc": Color(red: 0.38, green: 0.38, blue: 0.38),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: Prefs.tenKhachHang ?? "Tài khoản")
            settingsList
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

    private var settingsList: some View {
        List {
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                if let vi {
                    Section {
                        viCard(vi)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Địa chỉ đã lưu") {
                    if diaChiList.isEmpty {
                        Text("Chưa có địa chỉ nào — nhập ở bước đặt hàng sẽ tự lưu lại.")
                            .font(.system(size: 13)).foregroundColor(Theme.textFaint)
                    } else {
                        ForEach(diaChiList) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text((item.isDefault ? "★ " : "") + item.diaChi)
                                    if !item.isDefault {
                                        Button("Đặt làm mặc định") { Task { await datMacDinh(item.id) } }
                                            .font(.system(size: 12)).foregroundColor(Theme.primary)
                                    }
                                }
                                Spacer()
                                Button { Task { await xoaDiaChi(item.id) } } label: {
                                    Image(systemName: "xmark").foregroundColor(Theme.danger)
                                }
                            }
                        }
                    }
                }

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
        .listStyle(.plain)
    }

    private func viCard(_ vi: KhachHangVi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("👑 Hạng \(vi.hang)")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(hangColor[vi.hang] ?? Theme.primary).clipShape(Capsule())
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatTien(vi.soDu)).font(.system(size: 20, weight: .bold))
                    Text("Số dư ví").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            }
            HStack(spacing: 12) {
                statBox(String(format: "%.0f", vi.diemThangNay), "Điểm tháng này")
                statBox(String(format: "%.0f", vi.diemThangTruoc), "Điểm tháng trước")
            }
            if vi.tongNo > 0 {
                Text("Công nợ hiện tại: \(formatTien(vi.tongNo))").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.danger)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
        .padding(.horizontal)
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.primary)
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        async let sessionsTask = APIClient.shared.getSessions()
        async let diaChiTask = APIClient.shared.getDiaChiList()
        async let viTask = APIClient.shared.getVi()
        (sessions, diaChiList, vi) = await (sessionsTask, diaChiTask, viTask)
        loading = false
    }

    private func xoaDiaChi(_ id: String) async {
        let result = await APIClient.shared.xoaDiaChi(id)
        if result.success { diaChiList.removeAll { $0.id == id } }
    }

    private func datMacDinh(_ id: String) async {
        let result = await APIClient.shared.datDiaChiMacDinh(id)
        if result.success {
            diaChiList = diaChiList.map { DiaChiKhachHang(id: $0.id, diaChi: $0.diaChi, isDefault: $0.id == id, lat: $0.lat, long: $0.long) }
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
