import SwiftUI

/// Công nợ hiện tại — GET /api/dat-hang/cong-no-lich-su, lọc client-side chỉ giữ hoá đơn CÒN NỢ
/// (conLai > 0). Trước 2026-09-22 hiện cả lịch sử (kể cả đơn đã trả hết) khiến khách khó thấy ngay
/// đang nợ đơn nào — giờ chỉ hiện đơn còn nợ, dùng chung style cardBox/cardRow với các tab khác cho
/// đồng bộ. Card tổng nợ ở đầu đã bỏ (feedback 2026-09-23) — tổng đã hiện sẵn ở SettingsView rồi,
/// thừa khi vào đây lại thấy lần nữa.
struct LichSuCongNoView: View {
    @State private var items: [CongNoLichSu] = []
    @State private var loading = true

    private var conNo: [CongNoLichSu] { items.filter { $0.conLai > 0 } }

    var body: some View {
        Group {
            if loading {
                fullScreenLoading()
            } else if conNo.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.success)
                    Text("Bạn không còn công nợ nào.").foregroundColor(Theme.textFaint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 2026-09-27: đổi sang dạng PHẲNG (List(.plain), không card/pastel/shadow) khớp
                // Đơn hàng/Lịch sử Xu — bỏ hẳn thanh màu bên trái + nền pastel riêng của màn này.
                List {
                    ForEach(conNo) { item in
                        hoaDonRow(item)
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Công nợ hiện tại")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// Khác staff (CongNoRowView bên AppQuanLyIOS) ở nhãn phụ: staff hiện TÊN KHÁCH (nhiều khách khác
    /// nhau); khách chỉ xem đơn của chính mình nên tên khách vô nghĩa (luôn là chính họ) — thay bằng
    /// PHÂN LOẠI (Giao hàng/Mang về/Tại quán) cho có ích hơn. Bỏ hẳn mã hoá đơn (vd "HD5e5146d7", vô
    /// nghĩa với khách — feedback 2026-09-22). Số tiền còn nợ vẫn giữ đỏ (Theme.danger) để dễ thấy là
    /// cảnh báo (feedback 2026-09-23).
    private func hoaDonRow(_ item: CongNoLichSu) -> some View {
        // Đơn Ship có địa chỉ thì gộp luôn vào dòng đầu ("Giao hàng tại: ...") thay vì tách riêng
        // nhãn "Giao hàng" + 1 dòng địa chỉ bên dưới — đỡ dư dòng (feedback 2026-09-23).
        let diaChi = item.phanLoai == "Ship" ? item.diaChiText?.trimmingCharacters(in: .whitespaces) : nil
        let dongDau = (diaChi?.isEmpty == false) ? "Giao hàng tại: \(diaChi!)" : phanLoaiLabel(item.phanLoai)

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dongDau).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textMuted).lineLimit(2)
                Text(item.tenMonSummary.isEmpty ? "Hoá đơn" : item.tenMonSummary)
                    .font(.system(size: 14))
                    .lineLimit(6)
                // Đã trả 1 phần thì thanhTien > conLai, mới cần hiện thêm dòng "Tổng" để phân biệt
                // — chưa trả gì thì 2 số bằng nhau, hiện cả 2 chỉ dư thừa (feedback 2026-09-22).
                if item.conLai < item.thanhTien {
                    Text("Tổng: \(formatTien(item.thanhTien))").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatUtcShort(item.ngayNo)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                Text(formatTien(item.conLai)).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.danger)
            }
        }
        .padding(.vertical, 6)
    }

    /// Cùng cách map PhanLoai với OrderDetailView ("Ship"/"Mv"/khác) — gom về đây vì dùng lại ở đây.
    private func phanLoaiLabel(_ phanLoai: String) -> String {
        switch phanLoai {
        case "Ship": return "Giao hàng"
        case "Mv": return "Mang về"
        default: return "Tại quán"
        }
    }

    /// FIX 2026-09-23 (lệch giờ +7 phát hiện qua ảnh chụp thật): HoaDon.NgayNo tính từ
    /// VietnamTime.Now (HoaDonNgayNoHelper.TinhNgayNo, đã LÀ giờ VN, Kind=Unspecified, KHÔNG PHẢI
    /// UTC thật) — bản cũ ép "Z" rồi quy đổi Asia/Ho_Chi_Minh làm CỘNG THÊM +7 giờ nữa (double-
    /// shift). Đổi sang parse THẲNG bằng chính giờ VN, không quy đổi gì — cùng cách
    /// formatThongBaoTime (ThongBaoView.swift) đã làm đúng cho NgayTao thông báo.
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
    }
}
