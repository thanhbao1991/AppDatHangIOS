import SwiftUI

/// Công nợ hiện tại — GET /api/dat-hang/cong-no-lich-su, lọc client-side chỉ giữ hoá đơn CÒN NỢ
/// (conLai > 0). Trước 2026-09-22 hiện cả lịch sử (kể cả đơn đã trả hết) khiến khách khó thấy ngay
/// đang nợ đơn nào — giờ chỉ hiện đơn còn nợ, kèm card tổng nợ ở đầu, dùng chung style
/// cardBox/cardRow với các tab khác cho đồng bộ.
struct LichSuCongNoView: View {
    @State private var items: [CongNoLichSu] = []
    @State private var loading = true

    private var conNo: [CongNoLichSu] { items.filter { $0.conLai > 0 } }
    private var tongConLai: Double { conNo.reduce(0) { $0 + $1.conLai } }

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
                    cardRow(topExtra: 6) { tongCard }
                    ForEach(conNo) { item in
                        cardRow { hoaDonCard(item) }
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

    private var tongCard: some View {
        cardBox {
            Text("TỔNG CÒN NỢ").font(.system(size: 12, weight: .bold)).tracking(0.6).foregroundColor(Theme.textMuted)
            Text(formatTien(tongConLai)).font(.system(size: 26, weight: .heavy)).foregroundColor(Theme.danger)
            Text("\(conNo.count) hoá đơn chưa thanh toán hết").font(.system(size: 12)).foregroundColor(Theme.textFaint)
        }
    }

    private func hoaDonCard(_ item: CongNoLichSu) -> some View {
        cardBox {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(Theme.danger)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.maHoaDon).font(.system(size: 14, weight: .bold))
                    Text(formatUtcShort(item.ngayNo)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    // Đã trả 1 phần thì thanhTien > conLai, mới cần hiện thêm dòng "Tổng" để phân biệt
                    // — chưa trả gì thì 2 số bằng nhau, hiện cả 2 chỉ dư thừa (feedback 2026-09-22).
                    if item.conLai < item.thanhTien {
                        Text("Tổng: \(formatTien(item.thanhTien))").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                    }
                    Text(formatTien(item.conLai)).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.danger)
                    Text("còn nợ").font(.system(size: 10)).foregroundColor(Theme.textFaint)
                }
            }
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
