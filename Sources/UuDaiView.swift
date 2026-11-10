import SwiftUI

extension Notification.Name {
    /// Phát sau khi điểm danh/mở hộp quà xong để MainTabView cập nhật chấm đỏ trên tab Ưu đãi.
    static let uuDaiDaThayDoi = Notification.Name("uuDaiDaThayDoi")
}

/// Port từ UuDaiScreen.tsx — vòng quay may mắn. Ngày sinh (khai báo + nhận quà sinh nhật) đã chuyển
/// sang SettingsView (mục "Thông tin cá nhân", tab Tài khoản) — đây là thông tin cá nhân, không phải
/// phần thưởng, nên không thuộc tab Ưu đãi. Thẻ sưu tập ly VÀ giới thiệu bạn bè đã XOÁ HẲN 2026-09-23
/// (backend không còn endpoint the-tem/gioi-thieu nữa — yêu cầu "app đơn giản thôi").
struct UuDaiView: View {
    var notificationBell: AnyView
    /// false khi nhúng trong UuDaiVoucherView (thanh tiêu đề do view cha vẽ).
    var showHeader: Bool = true

    // Có dữ liệu lần trước (BoNhoTam) thì hiện ngay, load() tải lại rồi thay vào (09/11/2026).
    @State private var loading = BoNhoTam.diemDanh == nil

    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    // -1 = chưa tải xong/lỗi (ẩn dòng chữ), >=0 = số lượt thật. Cập nhật lại NGAY sau mỗi lần quay
    // từ VongQuayResult.soLuotConLai (server trả kèm), không cần gọi thêm request.
    @State private var soLuotConLai = BoNhoTam.soLuotConLai ?? -1
    @State private var alertMessage: (title: String, message: String)?

    @State private var diemDanh: DiemDanhInfo? = BoNhoTam.diemDanh
    @State private var dangDiemDanh = false
    @State private var baoNhanh: String?

    @State private var soDuXu: Double?
    @State private var nhanNapXu: String?
    @State private var showTheLe = false

    @State private var boxScale: CGFloat = 1
    @State private var boxRotation: Double = 0
    // quaMo: hộp mở (nắp bật ra + ánh sáng + xu) ngay khi chạm, giữ vài giây sau khi có kết quả rồi đóng lại.
    @State private var quaMo = false

    var body: some View {
        VStack(spacing: 0) {
            if showHeader { TitleBar(title: "Ưu đãi", icon: "gift", centerTitle: true, trailing: notificationBell) }

            Group {
                if loading {
                    fullScreenLoading()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Bỏ card số dư Xu + nút Nạp Xu ở tab Ưu đãi (chủ quán 2026-11-07) — Nạp Xu và số dư vẫn ở card Xu tab Tài khoản.
                            diemDanhCard
                            vongQuayCard
                        }
                        .padding(.top, 6)
                    }
                    .refreshable { await load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        // Ngày 1–6: báo nhanh tự ẩn (không bắt bấm đóng); ngày 7 mới dùng popup (có voucher cần đọc).
        .overlay(alignment: .top) {
            if let t = baoNhanh {
                Text(t)
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.success))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .padding(.top, showHeader ? 70 : 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: baoNhanh)
        .task { await load() }
        .onDisappear { luuBoNhoTam() } // giữ cả lượt quay/điểm danh vừa làm
        .navigationDestination(isPresented: $showTheLe) { TheLeXuView() }
        .popupHost { host in
            host.alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(alertMessage?.message ?? "")
            }
        }
    }

    /// Icon Xu dùng chung — xem xuIcon(_:) trong Theme.swift.
    private func xuIcon(_ size: CGFloat) -> some View { Theme.xuIcon(size) }

    /// "Điểm danh nhận Xu" — chu kỳ 7 ngày LIÊN TIẾP, thưởng Xu THẲNG (không random như vòng quay).
    /// Bỏ lỡ 1 ngày là chuỗi reset về ngày 1 (khác vòng quay không quan tâm hôm qua) — xem
    /// GamificationService.DiemDanhNhanXuAsync ở backend.
    private var diemDanhCard: some View {
        Group {
            if let dd = diemDanh {
                cardBox {
                    // Bỏ tiêu đề "Điểm danh nhận Xu" (chủ quán thử 2026-11-07) — nút "Điểm danh nhận N Xu" dưới đã nói rõ.
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            diemDanhDayBox(day: day, info: dd)
                        }
                    }

                    // "Đã điểm danh" là trạng thái HOÀN THÀNH (tích cực), không phải "không dùng
                    // được" — nếu dùng chung nút disable mờ xám như "hết lượt quay" thì trông như 2
                    // trạng thái giống hệt nhau (bị khoá) trong khi ý nghĩa ngược nhau hẳn.
                    if dd.daDiemDanhHomNay {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Bạn đã điểm danh hôm nay").fontWeight(.bold)
                        }
                        .foregroundColor(Theme.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Button {
                            Task { await lamDiemDanh() }
                        } label: {
                            if dangDiemDanh {
                                ProgressView().tint(.white)
                            } else {
                                Text("Điểm danh nhận \(formatXu(thuongChoDay(dd.ngayTiepTheo, dd)))").fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.gradientProminent).frame(maxWidth: .infinity)
                        .disabled(dangDiemDanh)
                    }
                    #if DEV_LOGIN
                    // Chỉ bản dev: dev login chỉ đọc (POST điểm danh bị chặn) → xem thử hiệu ứng sau khi bấm.
                    HStack(spacing: 8) {
                        Button("🧪 Thử ngày 1–6") {
                            hienKetQuaDiemDanh(ngay: 3, "+\(formatXu(dd.thuongThuong)) đã vào ví.")
                        }
                        Button("🧪 Thử ngày 7") {
                            let het = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
                            let f = DateFormatter(); f.dateFormat = "dd/MM"
                            hienKetQuaDiemDanh(ngay: 7, "Bạn đã điểm danh đủ 7 ngày liên tiếp!\n+\(formatXu(dd.thuongNgay7)) đã vào ví.\n\n🎁 Tặng thêm voucher \"7 Ngày Chăm Chỉ\" giảm 10% (tối đa 5.000đ), dùng đến hết ngày \(f.string(from: het)) — xem ở mục Voucher.")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.bordered).tint(Theme.primary)
                    .frame(maxWidth: .infinity)
                    #endif
                }
            }
        }
    }

    private func thuongChoDay(_ day: Int, _ info: DiemDanhInfo) -> Double {
        day >= 7 ? info.thuongNgay7 : info.thuongThuong
    }

    /// Số Xu ngắn gọn cho ô ngày (không kèm chữ "Xu" — 7 ô chen chúc trên 1 hàng, đã có icon đồng
    /// xu bên dưới làm rõ đơn vị rồi).
    private func soNgan(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    // Style port từ card "Điểm Danh Nhận Xu" kiểu Shopee: số thưởng NẰM TRÊN icon (không phải dưới),
    // nhãn ngày nằm NGOÀI/DƯỚI khung màu (không phải trong) — ô "hôm nay" viền màu nhấn nổi bật.
    // 7 ô LUÔN cùng 1 bố cục (số + icon) — ô đã điểm danh chỉ khác bằng badge tick nhỏ đè góc + làm
    // mờ nội dung, tránh trước đây ô "Hôm nay đã xong" thay hẳn bằng 1 icon to trơ trọi, nhìn như 2
    // bộ giao diện khác nhau ghép chung 1 hàng.
    @ViewBuilder
    private func diemDanhDayBox(day: Int, info: DiemDanhInfo) -> some View {
        // Ô đại diện "hôm nay" LUÔN là ngayTiepTheo — dù đã điểm danh (ngayTiepTheo = ngày vừa nhận)
        // hay chưa (ngayTiepTheo = ngày mục tiêu sắp nhận).
        let isToday = day == info.ngayTiepTheo
        let daXong = info.daDiemDanhHomNay ? info.ngayTiepTheo : max(0, info.ngayTiepTheo - 1)
        let daXongNgayNay = day <= daXong
        let isDay7 = day == 7

        VStack(spacing: 6) {
            VStack(spacing: 4) {
                Text("+\(soNgan(thuongChoDay(day, info)))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isDay7 ? .white : (daXongNgayNay ? Theme.textFaint : Theme.textMuted))
                if isDay7 {
                    Text("🏆").font(.system(size: 22))
                } else {
                    xuIcon(24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .opacity(daXongNgayNay ? 0.45 : 1)
            .background(isDay7 ? Theme.primary : Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isToday ? Theme.primary : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if daXongNgayNay {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.success)
                        .background(Circle().fill(.white).padding(1))
                        .offset(x: 5, y: -5)
                }
            }

            Text(isToday ? "Hôm nay" : (isDay7 ? "Ngày 7" : "N.\(day)"))
                .font(.system(size: 10, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? Theme.primary : Theme.textFaint)
        }
    }

    private var vongQuayCard: some View {
        cardBox {
            if let ketQuaQuay {
                Text("🎉 " + ketQuaQuay)
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            giftBoxView.frame(maxWidth: .infinity, alignment: .center)

            // Dòng trạng thái + nút ⓘ ở CUỐI dòng (chủ quán 2026-11-07, thay tiêu đề đã bỏ). ⓘ chứa câu ghi rõ Apple không tài
            // trợ chương trình quà tặng — App Store Review Guideline 5.3.2 (26/10/2026) — nên hiện ở mọi trạng thái.
            HStack(spacing: 5) {
                if dangQuay {
                    Text("Đang mở...")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.primary)
                } else if soLuotConLai == 0 {
                    Text("Mời bạn quay lại vào ngày mai nhé")
                        .font(.system(size: 12)).foregroundColor(Theme.textFaint)
                } else if soLuotConLai > 0 {
                    Text("👆 Chạm vào hộp quà để mở — còn \(soLuotConLai) lượt")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.textMuted)
                }
                Button {
                    alertMessage = ("Hộp quà may mắn", NoiDung.hopQuaTaiTro)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            #if DEV_LOGIN
            // Phiên dev-login chỉ đọc (server chặn mọi thao tác ghi → không mở quà thật được): nút này chạy đúng hiệu ứng mở
            // quà với kết quả mẫu, KHÔNG gọi server. Chỉ có ở bản dev.
            Button { xemThuMoQua() } label: {
                Text("🧪 Xem thử hiệu ứng mở quà")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif

            // Công khai tỉ lệ trúng (hộp quà có yếu tố ngẫu nhiên) — bảng tỉ lệ nằm trong trang Thể lệ Xu.
            Button { showTheLe = true } label: {
                Text("Tỉ lệ trúng · Thể lệ Xu")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // ===== Hộp quà may mắn (thay bánh xe — yêu cầu 2026-09-24 "làm hộp quà cho đơn giản") =====

    /// Còn lượt mà chưa mở: hộp lắc liên tục gợi khách chạm (chủ quán 2026-11-07).
    private var hopQuaCho: Bool { !dangQuay && !quaMo && soLuotConLai > 0 && !loading }

    // Ảnh hộp quà do chủ quán gửi (2026-11-07): QuaDong = hộp đóng nơ đỏ, QuaMo = hộp mở nắp bật ra, ánh sáng + xu ngôi sao bay.
    // Hai ảnh cùng đáy, hộp mở phóng to hơn vì có nắp + xu bay phía trên. Giải mã sẵn ảnh (byPreparingForDisplay) — lần đầu
    // hiện ảnh chưa giải mã gây khựng ngay lúc mở.
    @State private var anhDong: UIImage?
    @State private var anhMo: UIImage?

    private func chuanBiAnhHop() {
        guard anhMo == nil else { return }
        Task.detached(priority: .userInitiated) {
            let d = await UIImage(named: "QuaDong")?.byPreparingForDisplay()
            let m = await UIImage(named: "QuaMo")?.byPreparingForDisplay()
            await MainActor.run { anhDong = d; anhMo = m }
        }
    }

    private static let dongRong: CGFloat = 224   // bề rộng ảnh hộp đóng (pt)
    private static let moRong: CGFloat = 282     // bề rộng ảnh hộp mở (pt) — lớn hơn vì có nắp + xu bay
    private static let moCao: CGFloat = 282 * 1229 / 1168 // theo tỉ lệ ảnh mở

    @ViewBuilder
    private var giftBoxView: some View {
        ZStack(alignment: .bottom) {
            // Vòng sáng vàng phía sau, sáng + nở ra khi hộp mở.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.84, blue: 0.40).opacity(quaMo ? 0.55 : 0.24), Color(red: 1, green: 0.84, blue: 0.40).opacity(0)],
                    center: .center, startRadius: 4, endRadius: 130))
                .frame(width: 270, height: 270)
                .scaleEffect(quaMo ? 1.15 : 1)
                .offset(y: -10)

            // Lắc liên tục tính theo thời gian (TimelineView) — chắc chắn không bị animation khác cắt giữa chừng.
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !hopQuaCho)) { tl in
                let goc: Double = hopQuaCho ? 5 * sin(tl.date.timeIntervalSinceReferenceDate * 2 * .pi * 2.2) : 0
                ZStack(alignment: .bottom) {
                    (anhDong.map { Image(uiImage: $0) } ?? Image("QuaDong")).resizable().scaledToFit()
                        .frame(width: Self.dongRong)
                        .scaleEffect(quaMo ? 1.12 : 1, anchor: .bottom)
                        .opacity(quaMo ? 0 : 1)
                    // Mở: ảnh hộp mở nảy ra từ đáy (lò xo, vọt quá rồi về) — cảm giác nắp bật tung.
                    (anhMo.map { Image(uiImage: $0) } ?? Image("QuaMo")).resizable().scaledToFit()
                        .frame(width: Self.moRong)
                        .scaleEffect(quaMo ? 1 : 0.6, anchor: .bottom)
                        .opacity(quaMo ? 1 : 0)
                }
                .frame(width: Self.moRong, height: Self.moCao, alignment: .bottom)
                .scaleEffect(boxScale, anchor: .bottom)
                .rotationEffect(.degrees(boxRotation + goc), anchor: .bottom)
            }
        }
        .frame(height: Self.moCao + 8)
        .opacity(soLuotConLai == 0 && !quaMo ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onBoxTap() }
        .onAppear { chuanBiAnhHop() }
    }

    /// Mở hộp: ảnh hộp mở bật ra bằng lò xo; đóng lại: về hộp đóng.
    private func moHop() {
        withAnimation(.interpolatingSpring(stiffness: 170, damping: 10)) {
            boxRotation = 0
            boxScale = 1
            quaMo = true
        }
    }

    private func dongHop() {
        withAnimation(.easeInOut(duration: 0.4)) { quaMo = false }
    }

    private func onBoxTap() {
        guard !dangQuay, soLuotConLai != 0 else { return }
        // Chạm: dừng lắc (spin() đặt dangQuay) và MỞ NGAY — không đợi server mới mở, đỡ cảm giác trễ. Kết quả (dòng 🎉)
        // hiện khi server trả; lỗi thì đóng hộp lại và báo alert.
        moHop()
        Task {
            await spin()
            if ketQuaQuay != nil {
                try? await Task.sleep(nanoseconds: 2_800_000_000)
            }
            dongHop()
        }
    }

    #if DEV_LOGIN
    private func xemThuMoQua() {
        guard !dangQuay, !quaMo else { return }
        dangQuay = true
        ketQuaQuay = nil
        moHop()
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            dangQuay = false
            ketQuaQuay = "Xem thử: bạn nhận +500 Xu"
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            dongHop()
        }
    }
    #endif

    private func load() async {
        async let quay = APIClient.shared.getVongQuayInfo()
        async let diemDanhKq = APIClient.shared.getDiemDanhInfo()
        async let viKq = APIClient.shared.getVi()
        let quayKq = await quay
        let ddKq = await diemDanhKq
        // Lỗi mạng thì giữ số cũ, không xoá về rỗng.
        if let quayKq { soLuotConLai = quayKq.soLuotConLai }
        if let ddKq { diemDanh = ddKq }
        // Tab này không còn hiện số dư Xu (bỏ 07/11) → không bắt khách chờ /vi (chậm nhất) mới hết vòng xoay.
        loading = false
        luuBoNhoTam()
        if let vi = await viKq {
            soDuXu = vi.soDu
            nhanNapXu = vi.nhanNapXu
        }
    }

    private func luuBoNhoTam() {
        if soLuotConLai >= 0 { BoNhoTam.soLuotConLai = soLuotConLai }
        if let diemDanh { BoNhoTam.diemDanh = diemDanh }
    }

    private func spin() async {
        guard !dangQuay, soLuotConLai != 0 else { return }
        dangQuay = true
        ketQuaQuay = nil
        let res = await APIClient.shared.quayVongQuay()
        guard res.isSuccess, let data = res.data else {
            dangQuay = false
            alertMessage = ("Chưa mở được", res.message ?? "")
            return
        }
        soLuotConLai = data.soLuotConLai
        if data.soTienThuong > 0 {
            soDuXu = await APIClient.shared.getVi()?.soDu ?? soDuXu
        }
        ketQuaQuay = data.label
        dangQuay = false
        NotificationCenter.default.post(name: .uuDaiDaThayDoi, object: nil)
    }

    /// Ngày 1–6: báo nhanh tự ẩn 2,5s; ngày 7: popup (có voucher cần đọc).
    private func hienKetQuaDiemDanh(ngay: Int, _ m: String) {
        if ngay >= 7 {
            alertMessage = ("🎉 Chúc mừng!", m)
        } else {
            baoNhanh = "✓ Điểm danh thành công — \(m)"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                baoNhanh = nil
            }
        }
    }

    private func lamDiemDanh() async {
        dangDiemDanh = true
        defer { dangDiemDanh = false }
        let res = await APIClient.shared.diemDanh()
        if res.isSuccess {
            diemDanh = await APIClient.shared.getDiemDanhInfo() ?? diemDanh
            soDuXu = await APIClient.shared.getVi()?.soDu ?? soDuXu
            NotificationCenter.default.post(name: .uuDaiDaThayDoi, object: nil)
            // 10/11/2026: chúc mừng sau khi bấm — câu chữ từ server (ngày 7 kèm voucher "7 Ngày Chăm Chỉ").
            if let m = res.message, !m.isEmpty { hienKetQuaDiemDanh(ngay: res.data?.ngay ?? 0, m) }
        } else {
            alertMessage = ("Chưa điểm danh được", res.message ?? "")
        }
    }
}
