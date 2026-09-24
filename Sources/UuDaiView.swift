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

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Ưu đãi", icon: "gift", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    fullScreenLoading()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
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
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    /// Header thống nhất cho mọi card — icon trong khung tròn màu nhấn + tiêu đề, thay vì emoji nằm
    /// trơn cạnh chữ (trước đây 3 card trông đều na ná nhau, khó phân biệt loại ưu đãi khi lướt nhanh).
    private func cardHeader(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(Theme.primaryTint)
                .clipShape(Circle())
            Text(title).font(.system(size: 16, weight: .bold))
            Spacer()
        }
    }

    /// "Điểm danh nhận Xu" — chu kỳ 7 ngày LIÊN TIẾP, thưởng Xu THẲNG (không random như vòng quay).
    /// Bỏ lỡ 1 ngày là chuỗi reset về ngày 1 (khác vòng quay không quan tâm hôm qua) — xem
    /// GamificationService.DiemDanhNhanXuAsync ở backend.
    private var diemDanhCard: some View {
        Group {
            if let dd = diemDanh {
                cardBox {
                    cardHeader("🗓️", "Điểm danh nhận Xu")
                    Text("Điểm danh liên tiếp 7 ngày — bỏ lỡ 1 ngày là tính lại từ đầu.")
                        .font(.system(size: 13)).foregroundColor(Theme.textMuted)

                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            diemDanhDayBox(day: day, info: dd)
                        }
                    }

                    Button {
                        Task { await lamDiemDanh() }
                    } label: {
                        if dangDiemDanh {
                            ProgressView().tint(.white)
                        } else if dd.daDiemDanhHomNay {
                            Text("Đã điểm danh hôm nay ✓").fontWeight(.bold)
                        } else {
                            Text("Điểm danh nhận \(formatXu(thuongChoDay(dd.ngayTiepTheo, dd)))").fontWeight(.bold)
                        }
                    }
                    .buttonStyle(.gradientProminent).frame(maxWidth: .infinity)
                    .disabled(dd.daDiemDanhHomNay || dangDiemDanh)
                }
            }
        }
    }

    private func thuongChoDay(_ day: Int, _ info: DiemDanhInfo) -> Double {
        day >= 7 ? info.thuongNgay7 : info.thuongThuong
    }

    @ViewBuilder
    private func diemDanhDayBox(day: Int, info: DiemDanhInfo) -> some View {
        // Số ngày đã điểm danh XONG trong chu kỳ hiện tại — nếu hôm nay đã điểm danh thì ngayTiepTheo
        // CHÍNH là ngày vừa nhận; chưa điểm danh thì ngày trước đó (ngayTiepTheo-1) mới là đã xong.
        let daXong = info.daDiemDanhHomNay ? info.ngayTiepTheo : max(0, info.ngayTiepTheo - 1)
        let laHomNay = !info.daDiemDanhHomNay && day == info.ngayTiepTheo
        let daXongNgayNay = day <= daXong

        VStack(spacing: 4) {
            Text(day == 7 ? "🏆" : (daXongNgayNay ? "✅" : "🪙"))
                .font(.system(size: day == 7 ? 20 : 16))
            Text("+\(formatXu(thuongChoDay(day, info)))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(daXongNgayNay ? Theme.textFaint : Theme.textMuted)
            Text(day == 7 ? "Ngày 7" : "N.\(day)")
                .font(.system(size: 9)).foregroundColor(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(day == 7 ? Theme.primaryTint : Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(laHomNay ? Theme.primary : Color.clear, lineWidth: 2)
        )
        .opacity(daXongNgayNay ? 0.55 : 1)
    }

    private var vongQuayCard: some View {
        cardBox {
            cardHeader("🎡", "Vòng quay may mắn")
            Text("Mỗi ngày 1 lượt quay miễn phí — thử vận may nhận thưởng Xu!").font(.system(size: 13)).foregroundColor(Theme.textMuted)
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
        soLuotConLai = await quay?.soLuotConLai ?? -1
        lichSu = await lichSuKq ?? []
        diemDanh = await diemDanhKq
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
        } else {
            alertMessage = ("Chưa điểm danh được", res.message ?? "")
        }
    }
}
