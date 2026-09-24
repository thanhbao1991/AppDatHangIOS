import SwiftUI

/// Port từ UuDaiScreen.tsx — vòng quay may mắn. Ngày sinh (khai báo + nhận quà sinh nhật) đã chuyển
/// sang SettingsView (mục "Thông tin cá nhân", tab Tài khoản) — đây là thông tin cá nhân, không phải
/// phần thưởng, nên không thuộc tab Ưu đãi. Thẻ sưu tập ly VÀ giới thiệu bạn bè đã XOÁ HẲN 2026-09-23
/// (backend không còn endpoint the-tem/gioi-thieu nữa — yêu cầu "app đơn giản thôi").
struct UuDaiView: View {
    var notificationBell: AnyView

    @State private var loading = true

    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    // -1 = chưa tải xong/lỗi (ẩn dòng chữ), >=0 = số lượt thật. Cập nhật lại NGAY sau mỗi lần quay
    // từ VongQuayResult.soLuotConLai (server trả kèm), không cần gọi thêm request.
    @State private var soLuotConLai = -1
    @State private var alertMessage: (title: String, message: String)?
    @State private var lichSu: [VongQuayLichSuItem] = []
    @State private var hienLichSu = false

    @State private var diemDanh: DiemDanhInfo?
    @State private var dangDiemDanh = false

    @State private var soDuXu: Double?
    @State private var showLichSuVi = false

    @State private var wheelItems: [VongQuayMoTaItem] = []
    @State private var wheelRotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Ưu đãi", icon: "gift", centerTitle: true, trailing: notificationBell)

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
        .navigationDestination(isPresented: $showLichSuVi) { LichSuViView() }
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    /// Icon Xu vẽ tay bằng shape (thay vì emoji 🪙 — bị chê "xấu", render phẳng/xỉn màu tuỳ font hệ
    /// thống) — đồng xu vàng gradient + viền đậm + chữ "Xu", giống style badge "S" của Shopee.
    @ViewBuilder
    private func xuIcon(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.85, blue: 0.4), Color(red: 0.93, green: 0.63, blue: 0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(Color(red: 0.75, green: 0.46, blue: 0.02), lineWidth: max(1, size * 0.07))
            Text("Xu")
                .font(.system(size: size * 0.36, weight: .heavy))
                .foregroundColor(Color(red: 0.5, green: 0.29, blue: 0.02))
        }
        .frame(width: size, height: size)
    }

    /// Tổng Xu hiện có + lối vào Lịch sử ví — đặt đầu tab (kiểu Shopee) để khách thấy ngay "đang có
    /// bao nhiêu" trước khi lướt xuống các cách kiếm thêm (điểm danh/vòng quay).
    private var xuBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    xuIcon(28)
                    Text(soNgan(soDuXu ?? 0)).font(.system(size: 30, weight: .bold)).foregroundColor(.white)
                }
                Text("Số dư Xu hiện tại").font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Button {
                showLichSuVi = true
            } label: {
                HStack(spacing: 4) {
                    Text("Lịch sử").font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.white.opacity(0.22)).clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.primaryGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 6)
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
                            Text("Đã điểm danh hôm nay").fontWeight(.bold)
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
                    xuIcon(18)
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
            Text("Vòng quay may mắn")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
            if let ketQuaQuay {
                Text("🎉 " + ketQuaQuay)
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            wheelView.frame(maxWidth: .infinity, alignment: .center)

            if dangQuay {
                Text("Đang quay...")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if soLuotConLai == 0 {
                Text("Còn 0 lượt — quay lại vào ngày mai nhé")
                    .font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if soLuotConLai > 0 {
                Text("👆 Vuốt vào bánh xe để quay — còn \(soLuotConLai) lượt")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if !lichSu.isEmpty {
                Divider().padding(.top, 4)
                Button {
                    withAnimation { hienLichSu.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Lịch sử quay").font(.system(size: 13, weight: .medium))
                        Image(systemName: hienLichSu ? "chevron.up" : "chevron.down").font(.system(size: 11))
                    }
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 4)

                // Minh bạch — khách hay nghi ngờ vòng quay "giả", liệt kê CẢ lần không trúng mới
                // chứng minh được random thật, không chỉ khoe các lần trúng.
                if hienLichSu {
                    VStack(spacing: 0) {
                        ForEach(Array(lichSu.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                            }
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label).font(.system(size: 13, weight: .medium))
                                    Text(formatVNTime(item.thoiGian)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                                }
                                Spacer()
                                if item.trung {
                                    Text("+" + formatXu(item.thuong))
                                        .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.success)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    // ===== Bánh xe quay thật (thay nút bấm bằng vuốt, theo yêu cầu 2026-09-24) =====

    private let wheelSize: CGFloat = 200

    private let wheelPalette: [Color] = [
        Color(red: 0.98, green: 0.62, blue: 0.15),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.92, green: 0.35, blue: 0.45),
        Color(red: 0.36, green: 0.72, blue: 0.44),
        Color(red: 0.62, green: 0.44, blue: 0.86),
        Color(red: 0.95, green: 0.78, blue: 0.20),
    ]
    private func wheelColor(_ idx: Int) -> Color { wheelPalette[idx % wheelPalette.count] }

    /// Rút gọn Label đầy đủ (vd "+10.000đ vào ví 🏆") xuống phần "+10.000đ" để vừa trong 1 lát cắt.
    private func wheelShortLabel(_ label: String) -> String {
        label.split(separator: " ").first.map(String.init) ?? label
    }

    @ViewBuilder
    private var wheelView: some View {
        if wheelItems.isEmpty {
            ProgressView().frame(width: wheelSize, height: wheelSize)
        } else {
            ZStack {
                Canvas { context, size in
                    let total = wheelItems.reduce(0) { $0 + $1.trongSo }
                    guard total > 0 else { return }
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 2
                    var startDeg = 0.0
                    for (idx, item) in wheelItems.enumerated() {
                        let sweep = Double(item.trongSo) / Double(total) * 360
                        let endDeg = startDeg + sweep
                        var path = Path()
                        path.move(to: center)
                        let steps = max(2, Int(sweep / 6))
                        for s in 0...steps {
                            let t = startDeg + sweep * Double(s) / Double(steps)
                            let rad = t * .pi / 180
                            path.addLine(to: CGPoint(x: center.x + radius * sin(rad), y: center.y - radius * cos(rad)))
                        }
                        path.closeSubpath()
                        context.fill(path, with: .color(wheelColor(idx)))
                        context.stroke(path, with: .color(.white), lineWidth: 1.5)

                        let mid = startDeg + sweep / 2
                        let labelRadius = radius * 0.62
                        let rad = mid * .pi / 180
                        let pt = CGPoint(x: center.x + labelRadius * sin(rad), y: center.y - labelRadius * cos(rad))
                        let resolved = context.resolve(
                            Text(wheelShortLabel(item.label))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        context.draw(resolved, at: pt)
                        startDeg = endDeg
                    }
                    let hubR = radius * 0.16
                    let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
                    context.fill(Path(ellipseIn: hubRect), with: .color(.white))
                    context.stroke(Path(ellipseIn: hubRect), with: .color(Theme.divider), lineWidth: 1)
                }
                .frame(width: wheelSize, height: wheelSize)
                .rotationEffect(.degrees(wheelRotation))
                .overlay(Circle().stroke(Theme.divider, lineWidth: 2))
                .clipShape(Circle())

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.primary)
                    .offset(y: -wheelSize / 2 - 8)
            }
            .frame(width: wheelSize, height: wheelSize + 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard !dangQuay, soLuotConLai != 0 else { return }
                        let dist = (value.translation.width * value.translation.width
                            + value.translation.height * value.translation.height).squareRoot()
                        guard dist > 24 else { return }
                        let power = min(dist / 200, 1)
                        Task { await spin(power: power) }
                    }
            )
            .opacity(dangQuay || soLuotConLai == 0 ? 0.55 : 1)
        }
    }

    /// Xoay bánh xe sao cho lát cắt trúng (khớp Label server trả) dừng đúng dưới mũi tên — power
    /// (0-1, từ độ mạnh cú vuốt) quyết định số vòng xoay thêm (3-7 vòng) cho cảm giác "xoay thật".
    private func animateWheel(toLabel label: String, power: Double, completion: @escaping () -> Void) {
        let total = wheelItems.reduce(0) { $0 + $1.trongSo }
        guard total > 0 else { completion(); return }

        var cum = 0.0
        var centerAngle = 0.0
        for item in wheelItems {
            let sweep = Double(item.trongSo) / Double(total) * 360
            if item.label == label {
                centerAngle = cum + sweep / 2
                break
            }
            cum += sweep
        }

        let turns = 3 + min(max(power, 0), 1) * 4
        let neededMod = (360 - centerAngle).truncatingRemainder(dividingBy: 360)
        let minTarget = wheelRotation + turns * 360
        let currentBase = minTarget.truncatingRemainder(dividingBy: 360)
        var diff = neededMod - currentBase
        if diff < 0 { diff += 360 }
        let target = minTarget + diff
        let duration = 2.2 + power * 0.6

        withAnimation(.easeOut(duration: duration)) {
            wheelRotation = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: completion)
    }

    /// Cùng cách parse với LichSuViView.formatUtcShort — ThoiGian là VietnamTime.Now (đã là giờ VN,
    /// Kind=Unspecified), parse thẳng không quy đổi timezone thêm lần nữa.
    private func formatVNTime(_ iso: String) -> String {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        inF.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        inF.locale = Locale(identifier: "en_US_POSIX")
        guard let date = inF.date(from: String(iso.prefix(19))) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "HH:mm dd/MM/yyyy"
        out.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return out.string(from: date)
    }

    private func load() async {
        async let quay = APIClient.shared.getVongQuayInfo()
        async let lichSuKq = APIClient.shared.getVongQuayLichSu()
        async let diemDanhKq = APIClient.shared.getDiemDanhInfo()
        async let viKq = APIClient.shared.getVi()
        async let moTaKq = APIClient.shared.getVongQuayMoTa()
        soLuotConLai = await quay?.soLuotConLai ?? -1
        lichSu = await lichSuKq ?? []
        diemDanh = await diemDanhKq
        soDuXu = await viKq?.soDu
        wheelItems = await moTaKq ?? []
        loading = false
    }

    /// power (0-1) = độ mạnh cú vuốt kích hoạt quay — chỉ quyết định TỐC ĐỘ/số vòng xoay hiển thị,
    /// KHÔNG ảnh hưởng kết quả (server quyết định trước, animateWheel chỉ xoay tới đúng ô đó).
    private func spin(power: Double) async {
        guard !dangQuay, soLuotConLai != 0 else { return }
        dangQuay = true
        ketQuaQuay = nil
        let res = await APIClient.shared.quayVongQuay()
        guard res.isSuccess, let data = res.data else {
            dangQuay = false
            alertMessage = ("Chưa quay được", res.message ?? "")
            return
        }
        soLuotConLai = data.soLuotConLai
        lichSu = await APIClient.shared.getVongQuayLichSu() ?? lichSu
        if data.soTienThuong > 0 {
            soDuXu = await APIClient.shared.getVi()?.soDu ?? soDuXu
        }
        animateWheel(toLabel: data.label, power: power) {
            ketQuaQuay = data.label
            dangQuay = false
        }
    }

    private func lamDiemDanh() async {
        dangDiemDanh = true
        defer { dangDiemDanh = false }
        let res = await APIClient.shared.diemDanh()
        if res.isSuccess {
            diemDanh = await APIClient.shared.getDiemDanhInfo() ?? diemDanh
            soDuXu = await APIClient.shared.getVi()?.soDu ?? soDuXu
        } else {
            alertMessage = ("Chưa điểm danh được", res.message ?? "")
        }
    }
}
