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
            Button {
                Task { await quay() }
            } label: {
                if dangQuay { ProgressView().tint(.white) } else { Text("Quay ngay 🎲").fontWeight(.bold) }
            }
            .buttonStyle(.gradientProminent).frame(maxWidth: .infinity)
            .disabled(dangQuay || soLuotConLai == 0)
            // -1 = chưa tải xong (ẩn hẳn dòng chữ, tránh nháy "0 lượt" sai trước khi API trả về).
            if soLuotConLai >= 0 {
                Text("Còn \(soLuotConLai) lượt")
                    .font(.system(size: 12)).foregroundColor(Theme.textFaint)
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
        soLuotConLai = await quay?.soLuotConLai ?? -1
        lichSu = await lichSuKq ?? []
        diemDanh = await diemDanhKq
        soDuXu = await viKq?.soDu
        loading = false
    }

    private func quay() async {
        dangQuay = true
        ketQuaQuay = nil
        defer { dangQuay = false }
        let res = await APIClient.shared.quayVongQuay()
        if res.isSuccess, let data = res.data {
            ketQuaQuay = data.label
            soLuotConLai = data.soLuotConLai
            lichSu = await APIClient.shared.getVongQuayLichSu() ?? lichSu
            if data.soTienThuong > 0 {
                soDuXu = await APIClient.shared.getVi()?.soDu ?? soDuXu
            }
        } else {
            alertMessage = ("Chưa quay được", res.message ?? "")
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
