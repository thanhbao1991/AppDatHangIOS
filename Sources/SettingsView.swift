import SwiftUI

/// Port từ SettingsScreen.tsx — ví/hạng thành viên, địa chỉ đã lưu. Các thao tác bảo mật/tài khoản
/// (đổi mật khẩu, thiết bị đăng nhập, đăng xuất, xoá tài khoản) đã tách sang TaiKhoanBaoMatView,
/// mở qua icon bánh răng ở MainTabView (chỉ hiện khi đang ở tab này) — tránh trộn với ví/địa chỉ.
struct SettingsView: View {
    @Binding var isLoggedIn: Bool
    var notificationBell: AnyView
    var accountSettingsGear: AnyView

    @State private var diaChiList: [DiaChiKhachHang] = []
    @State private var vi: KhachHangVi?
    @State private var loading = true

    private let hangColor: [String: Color] = [
        "Kim Cương": Color(red: 0, green: 0.51, blue: 0.56),
        "Vàng": Color(red: 0.72, green: 0.53, blue: 0.04),
        "Bạc": Color(red: 0.38, green: 0.38, blue: 0.38),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: Prefs.tenKhachHang ?? "Tài khoản", trailing: AnyView(
                HStack(spacing: 4) { notificationBell; accountSettingsGear }
            ))
            settingsList
        }
        .task { await load() }
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
                    Text(formatXu(vi.soDu)).font(.system(size: 20, weight: .bold))
                    Text("Số dư Xu").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            }
            HStack(spacing: 12) {
                statBox(String(format: "%.0f", vi.diemThangNay), "Điểm tháng này")
                statBox(String(format: "%.0f", vi.diemThangTruoc), "Điểm tháng trước")
            }
            if vi.tongNo > 0 {
                Text("Công nợ hiện tại: \(formatTien(vi.tongNo))").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.danger)
            }
            NavigationLink { LichSuViView() } label: {
                HStack {
                    Text("Lịch sử Xu").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
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

    private func load() async {
        async let diaChiTask = APIClient.shared.getDiaChiList()
        async let viTask = APIClient.shared.getVi()
        (diaChiList, vi) = await (diaChiTask, viTask)
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
}
