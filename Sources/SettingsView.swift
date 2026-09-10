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

    @State private var sinhNhat: SinhNhatInfo?
    @State private var dobDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var dobChosen = false
    @State private var dangLuuSinhNhat = false
    @State private var dangNhanQua = false
    @State private var alertMessage: (title: String, message: String)?

    @State private var tenHienThi: String = Prefs.tenKhachHang ?? ""
    @State private var dangLuuTen = false

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
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    private var settingsList: some View {
        List {
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                if let vi {
                    cardSection { xuCard(vi) }
                    cardSection { diemHangCard(vi) }
                    if vi.tongNo > 0 {
                        cardSection { congNoCard(vi) }
                    }
                }

                cardSection { thongTinCaNhanCard }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    /// Section wrapper dùng chung cho mọi card ở tab Tài khoản — giữ đồng nhất khoảng cách/insets
    /// giữa các card (Xu, Điểm & Hạng, Công nợ) mà không lặp lại 2 modifier mỗi nơi.
    @ViewBuilder
    private func cardSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Section { content() }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
            .padding(.horizontal)
            .padding(.vertical, 6)
    }

    /// Card Xu — CHỈ số dư Xu (điểm thưởng quy đổi đơn hàng), tách hẳn khỏi Điểm/Hạng thành viên vì
    /// hai khái niệm khác nhau: Xu tiêu được như tiền, Điểm chỉ dùng xét hạng thành viên.
    private func xuCard(_ vi: KhachHangVi) -> some View {
        card {
            HStack {
                Text("🪙 Xu khả dụng").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textMuted)
                Spacer()
            }
            Text(formatXu(vi.soDu)).font(.system(size: 24, weight: .bold))
            NavigationLink { LichSuViView() } label: {
                HStack {
                    Text("Lịch sử Xu").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            }
        }
    }

    /// Card Điểm & Hạng thành viên đi CHUNG một card vì Hạng được xét trực tiếp từ điểm tích luỹ —
    /// không liên quan Xu.
    private func diemHangCard(_ vi: KhachHangVi) -> some View {
        card {
            HStack {
                Text("👑 Hạng \(vi.hang)")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(hangColor[vi.hang] ?? Theme.primary).clipShape(Capsule())
                Spacer()
            }
            HStack(spacing: 12) {
                statBox(String(format: "%.0f", vi.diemThangNay), "Điểm tháng này")
                statBox(String(format: "%.0f", vi.diemThangTruoc), "Điểm tháng trước")
            }
        }
    }

    /// Gộp tên hiển thị/sinh nhật/địa chỉ vào chung 1 card — trước đây là List Section trơn (chữ nền
    /// trong suốt, không viền/nền trắng) nên trông lạc nhịp so với 3 card Xu/Điểm/Công nợ phía trên.
    private var thongTinCaNhanCard: some View {
        card {
            Text("Thông tin cá nhân").font(.system(size: 16, weight: .bold))
            Divider()
            tenHienThiRow
            Divider()
            sinhNhatRow
            Divider()

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

    /// Tên hiển thị (biệt danh) trong app — chỉ đổi cách app hiện tên, không đụng tên thật khách lưu
    /// ở quán (chỉ nhân viên sửa được qua Desktop). Để trống + Lưu = xoá biệt danh, quay lại tên thật.
    private var tenHienThiRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tên hiển thị").font(.system(size: 14))
            HStack {
                TextField("Tên hiển thị trong app", text: $tenHienThi)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await luuTenHienThi() }
                } label: {
                    if dangLuuTen { ProgressView() } else { Text("Lưu") }
                }
                .buttonStyle(.bordered).tint(Theme.primary)
                .disabled(dangLuuTen || tenHienThi.trimmingCharacters(in: .whitespaces) == (Prefs.tenKhachHang ?? ""))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var sinhNhatRow: some View {
        if let sinhNhat {
            VStack(alignment: .leading, spacing: 6) {
                if let ngaySinh = sinhNhat.ngaySinh {
                    Text("🎂 Ngày sinh: \(formatDateVN(ngaySinh))").font(.system(size: 14))
                    if sinhNhat.dangTrongThangSinhNhat && !sinhNhat.daNhanQuaNamNay {
                        Button {
                            Task { await nhanQua() }
                        } label: {
                            if dangNhanQua { ProgressView() } else { Text("🎁 Nhận quà sinh nhật") }
                        }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    } else if sinhNhat.daNhanQuaNamNay {
                        Text("Đã nhận quà năm nay rồi, hẹn năm sau nhé!").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    }
                } else {
                    Text("🎂 Chưa khai ngày sinh").font(.system(size: 14))
                    Text("Nhập để nhận quà mừng sinh nhật mỗi năm.").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    HStack {
                        DatePicker("", selection: $dobDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .onChange(of: dobDate) { _ in dobChosen = true }
                        Button {
                            Task { await luuSinhNhat() }
                        } label: {
                            if dangLuuSinhNhat { ProgressView() } else { Text("Lưu") }
                        }
                        .buttonStyle(.bordered).tint(Theme.primary).disabled(dangLuuSinhNhat || !dobChosen)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func congNoCard(_ vi: KhachHangVi) -> some View {
        card {
            Text("Công nợ hiện tại").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textMuted)
            Text(formatTien(vi.tongNo)).font(.system(size: 24, weight: .bold)).foregroundColor(Theme.danger)
        }
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
        async let snTask = APIClient.shared.getSinhNhat()
        (diaChiList, vi, sinhNhat) = await (diaChiTask, viTask, snTask)
        loading = false
    }

    private func formatDateVN(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) ?? DateFormatter.iso8601NoTZ.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "dd/MM/yyyy"
        out.locale = Locale(identifier: "vi_VN")
        return out.string(from: date)
    }

    private func luuTenHienThi() async {
        let ten = tenHienThi.trimmingCharacters(in: .whitespaces)
        dangLuuTen = true
        defer { dangLuuTen = false }
        let res = await APIClient.shared.capNhatTenHienThi(ten.isEmpty ? nil : ten)
        if res.success {
            Prefs.tenKhachHang = ten.isEmpty ? nil : ten
            tenHienThi = ten
        } else {
            alertMessage = ("Lỗi", res.message ?? "")
        }
    }

    private func luuSinhNhat() async {
        guard dobChosen else {
            alertMessage = ("Chưa chọn ngày", "Chọn ngày sinh trước khi lưu.")
            return
        }
        dangLuuSinhNhat = true
        defer { dangLuuSinhNhat = false }
        let iso = ISO8601DateFormatter().string(from: dobDate)
        let res = await APIClient.shared.capNhatNgaySinh(iso)
        if res.success {
            dobChosen = false
            sinhNhat = await APIClient.shared.getSinhNhat()
        } else {
            alertMessage = ("Lỗi", res.message ?? "")
        }
    }

    private func nhanQua() async {
        dangNhanQua = true
        defer { dangNhanQua = false }
        let res = await APIClient.shared.nhanQuaSinhNhat()
        alertMessage = (res.isSuccess ? "🎂 Chúc mừng!" : "Chưa nhận được", res.message ?? "")
        if res.isSuccess { sinhNhat = await APIClient.shared.getSinhNhat() }
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

private extension DateFormatter {
    static let iso8601NoTZ: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
