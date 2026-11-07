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

    @State private var loading = true

    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    // -1 = chưa tải xong/lỗi (ẩn dòng chữ), >=0 = số lượt thật. Cập nhật lại NGAY sau mỗi lần quay
    // từ VongQuayResult.soLuotConLai (server trả kèm), không cần gọi thêm request.
    @State private var soLuotConLai = -1
    @State private var alertMessage: (title: String, message: String)?

    @State private var diemDanh: DiemDanhInfo?
    @State private var dangDiemDanh = false

    @State private var soDuXu: Double?
    @State private var nhanNapXu: String?
    @State private var showNapXu = false
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
                            xuBanner
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
        .task { await load() }
        .navigationDestination(isPresented: $showNapXu) { NapXuView(onXong: { showNapXu = false }) }
        .onChange(of: showNapXu) { dangMo in
            if !dangMo { Task { await load() } }
        }
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

    /// Tổng Xu hiện có + lối vào Nạp Xu (Lịch sử Xu vẫn ở tab Tài khoản) — đặt đầu tab (kiểu Shopee) để khách thấy ngay "đang có
    /// bao nhiêu" trước khi lướt xuống các cách kiếm thêm (điểm danh/vòng quay).
    private var xuBanner: some View {
        SoDuCard(icon: AnyView(xuIcon(36)), giaTri: SoDuCard.so(soDuXu ?? 0), chuThich: "Số dư Xu hiện tại",
                 nut: "Nạp Xu", nhanNut: nhanNapXu, iconNut: "plus.circle.fill", onNut: { showNapXu = true })
    }

    /// "Điểm danh nhận Xu" — chu kỳ 7 ngày LIÊN TIẾP, thưởng Xu THẲNG (không random như vòng quay).
    /// Bỏ lỡ 1 ngày là chuỗi reset về ngày 1 (khác vòng quay không quan tâm hôm qua) — xem
    /// GamificationService.DiemDanhNhanXuAsync ở backend.
    private var diemDanhCard: some View {
        Group {
            if let dd = diemDanh {
                cardBox {
                    Text("Điểm danh nhận Xu")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Divider()

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
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
            // App Store Review Guideline 5.3.2: chương trình quà tặng phải ghi rõ Apple không tài trợ — câu
            // này nằm trong icon ⓘ sau tiêu đề (26/10/2026, trước là dòng chữ nhỏ cố định dưới hộp quà).
            Button {
                alertMessage = ("Hộp quà may mắn", NoiDung.hopQuaTaiTro)
            } label: {
                (Text("Hộp quà may mắn ") + Text(Image(systemName: "info.circle")).foregroundColor(Theme.textMuted))
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            Divider()
            if let ketQuaQuay {
                Text("🎉 " + ketQuaQuay)
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            giftBoxView.frame(maxWidth: .infinity, alignment: .center)

            if dangQuay {
                Text("Đang mở...")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if soLuotConLai == 0 {
                Text("Mời bạn quay lại vào ngày mai nhé")
                    .font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if soLuotConLai > 0 {
                Text("👆 Chạm vào hộp quà để mở — còn \(soLuotConLai) lượt")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

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
                let goc: Double = hopQuaCho ? 5 * sin(tl.date.timeIntervalSinceReferenceDate * 2 * .pi * 3.2) : 0
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
        soLuotConLai = await quay?.soLuotConLai ?? -1
        diemDanh = await diemDanhKq
        let vi = await viKq
        soDuXu = vi?.soDu
        nhanNapXu = vi?.nhanNapXu
        loading = false
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

    private func lamDiemDanh() async {
        dangDiemDanh = true
        defer { dangDiemDanh = false }
        let res = await APIClient.shared.diemDanh()
        if res.isSuccess {
            diemDanh = await APIClient.shared.getDiemDanhInfo() ?? diemDanh
            soDuXu = await APIClient.shared.getVi()?.soDu ?? soDuXu
            NotificationCenter.default.post(name: .uuDaiDaThayDoi, object: nil)
        } else {
            alertMessage = ("Chưa điểm danh được", res.message ?? "")
        }
    }
}
