import SwiftUI

/// Công nợ hiện tại — GET /api/dat-hang/cong-no-lich-su, lọc client-side chỉ giữ hoá đơn CÒN NỢ
/// (conLai > 0). Trước 2026-09-22 hiện cả lịch sử (kể cả đơn đã trả hết) khiến khách khó thấy ngay
/// đang nợ đơn nào — giờ chỉ hiện đơn còn nợ. Card tổng nợ ở đầu đã bỏ (feedback 2026-09-23) — tổng
/// đã hiện sẵn ở SettingsView rồi. Thiết kế lại 09/11/2026: mỗi đơn một thẻ TK (TaiKhoanUI.swift).
struct LichSuCongNoView: View {
    /// Bấm "Thanh toán" ở thẻ Công nợ (tab Tài khoản) → tải xong tự mở luôn màn QR trả nợ.
    var moThanhToanNgay = false

    @State private var items: [CongNoLichSu] = []
    @State private var loading = true
    @State private var showThanhToan = false
    @State private var daTuMo = false

    private var conNo: [CongNoLichSu] { items.filter { $0.conLai > 0 } }
    private var tongNo: Double { conNo.reduce(0) { $0 + $1.conLai } }

    var body: some View {
        Group {
            if loading {
                fullScreenLoading()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if conNo.isEmpty {
                            TKTrong(icon: "checkmark.seal.fill", mau: Theme.success, chu: "Bạn không còn công nợ nào.")
                        } else {
                            ForEach(conNo) { item in hoaDonThe(item) }
                        }
                    }
                    .tkManHinh()
                }
                .background(Theme.bg)
                .refreshable { await load() }
                // Nút trả nợ nổi đáy: safeAreaInset + nền đặc (Material bị nháy — xem memory nút nổi SwiftUI).
                .safeAreaInset(edge: .bottom) {
                    if !conNo.isEmpty { nutThanhToan }
                }
            }
        }
        .navigationTitle("Công nợ hiện tại")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showThanhToan) {
            // Đơn nợ mới nhất (API sắp NgayNo giảm dần) làm "đơn chính" của mã QR — backend cộng phần nợ còn lại.
            if let dau = conNo.first {
                ThanhToanView(hoaDonId: dau.hoaDonId, tongNo: tongNo) { showThanhToan = false }
            }
        }
        // Quay về từ màn QR thì tải lại để thấy nợ đã được gạch (SePay webhook).
        .onChange(of: showThanhToan) { dangMo in
            if !dangMo { Task { await load() } }
        }
        .task { await load() }
    }

    private var nutThanhToan: some View {
        Button { showThanhToan = true } label: {
            Text("Thanh toán công nợ · \(formatTien(tongNo))")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.gradientProminent)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.bg.ignoresSafeArea(edges: .bottom))
    }

    /// Khách chỉ xem đơn của chính mình nên nhãn phụ là PHÂN LOẠI (Giao hàng/Mang về/Tại quán), không phải tên khách.
    /// Bỏ mã hoá đơn (vô nghĩa với khách — feedback 2026-09-22). Số tiền còn nợ giữ đỏ (feedback 2026-09-23).
    private func hoaDonThe(_ item: CongNoLichSu) -> some View {
        // Đơn Ship có địa chỉ thì gộp luôn vào dòng đầu ("Giao hàng tại: ...") — đỡ dư dòng (feedback 2026-09-23).
        let diaChi = item.phanLoai == "Ship" ? item.diaChiText?.trimmingCharacters(in: .whitespaces) : nil
        let dongDau = (diaChi?.isEmpty == false) ? "Giao hàng tại: \(diaChi!)" : phanLoaiLabel(item.phanLoai)

        return HStack(alignment: .top, spacing: 12) {
            TKIcon(ten: item.phanLoai == "Ship" ? "bicycle" : "bag.fill", mau: Theme.danger, co: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(dongDau).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textMuted).lineLimit(2)
                Text(item.tenMonSummary.isEmpty ? "Hoá đơn" : item.tenMonSummary)
                    .font(.system(size: 14))
                    .lineLimit(6)
                // Đã trả 1 phần thì thanhTien > conLai mới cần dòng "Tổng" để phân biệt (feedback 2026-09-22).
                if item.conLai < item.thanhTien {
                    Text("Tổng: \(formatTien(item.thanhTien))").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                }
                Text(formatUtcShort(item.ngayNo)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
            }
            Spacer(minLength: 8)
            Text(formatTien(item.conLai))
                .font(.system(size: 16, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundColor(Theme.danger)
        }
        .tkThe(dem: 14)
    }

    private func phanLoaiLabel(_ phanLoai: String) -> String {
        switch phanLoai {
        case "Ship": return "Giao hàng"
        case "Mv": return "Mang về"
        case "Mh": return "Mua hộ"
        default: return "Tại quán"
        }
    }

    /// HoaDon.NgayNo đã LÀ giờ VN (Kind=Unspecified) — parse thẳng giờ VN, không quy đổi (fix lệch +7 2026-09-23).
    private func formatUtcShort(_ iso: String) -> String {
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
        items = await APIClient.shared.getLichSuCongNo()
        loading = false
        if moThanhToanNgay && !daTuMo && !conNo.isEmpty {
            daTuMo = true
            showThanhToan = true
        }
    }
}
