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
                List {
                    ForEach(Array(conNo.enumerated()), id: \.element.id) { index, item in
                        cardRow(topExtra: index == 0 ? 6 : 0) { hoaDonCard(item) }
                    }
                }
                .cardListBackground()
                .refreshable { await load() }
            }
        }
        .navigationTitle("Công nợ hiện tại")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// Layout khớp CongNoRowView bên AppQuanLyIOS (tab Công nợ của nhân viên) — thanh màu bên trái +
    /// nền pastel đỏ nhạt + shadow + tóm tắt món làm dòng chính. Khác staff ở nhãn phụ: staff hiện
    /// TÊN KHÁCH (nhiều khách khác nhau); khách chỉ xem đơn của chính mình nên tên khách vô nghĩa
    /// (luôn là chính họ) — thay bằng PHÂN LOẠI (Giao hàng/Mang về/Tại quán) cho có ích hơn. Bỏ hẳn
    /// mã hoá đơn (vd "HD5e5146d7", vô nghĩa với khách — feedback 2026-09-22).
    private func hoaDonCard(_ item: CongNoLichSu) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.danger).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(phanLoaiLabel(item.phanLoai)).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textMuted)
                Text(item.tenMonSummary.isEmpty ? "Hoá đơn" : item.tenMonSummary)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(6)
                // Đã trả 1 phần thì thanhTien > conLai, mới cần hiện thêm dòng "Tổng" để phân biệt
                // — chưa trả gì thì 2 số bằng nhau, hiện cả 2 chỉ dư thừa (feedback 2026-09-22).
                if item.conLai < item.thanhTien {
                    Text("Tổng: \(formatTien(item.thanhTien))").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                }
                // Chỉ đơn Ship mới có địa chỉ giao — Mv/Tại quán không cần (feedback 2026-09-23).
                if item.phanLoai == "Ship", let diaChi = item.diaChiText, !diaChi.isEmpty {
                    Text("Giao hàng tại: \(diaChi)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textFaint)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatUtcShort(item.ngayNo)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                Text(formatTien(item.conLai)).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.danger)
            }
        }
        .padding(12)
        .background(Theme.danger.pastelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    /// Cùng cách map PhanLoai với OrderDetailView ("Ship"/"Mv"/khác) — gom về đây vì dùng lại ở đây.
    private func phanLoaiLabel(_ phanLoai: String) -> String {
        switch phanLoai {
        case "Ship": return "Giao hàng"
        case "Mv": return "Mang về"
        default: return "Tại quán"
        }
    }

    /// Backend trả DateTime "yyyy-MM-ddTHH:mm:ss.fffffff" (Kind=Unspecified nhưng thực chất UTC) —
    /// ép hậu tố "Z" trước khi parse để không bị hiểu nhầm thành giờ máy (cùng cách LichSuViView).
    private func formatUtcShort(_ iso: String) -> String {
        let trimmed = String(iso.prefix(19)) + "Z"
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: trimmed) else { return iso }
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
