import SwiftUI

/// Lịch sử công nợ — GET /api/dat-hang/cong-no-lich-su. Chỉ hoá đơn ĐÃ ghi nợ (NgayNo != null,
/// cùng định nghĩa TongNo ở card Xu+Công nợ bên SettingsView), giữ CẢ đơn đã trả hết (không chỉ đơn
/// còn nợ) để khách xem lại lịch sử — khác tab "Nợ" bên staff (chỉ liệt kê đơn còn nợ).
struct LichSuCongNoView: View {
    @State private var items: [CongNoLichSu] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                Text("Chưa có công nợ nào.").foregroundColor(Theme.textFaint).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.conLai > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(item.conLai > 0 ? Theme.danger : Theme.success)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.maHoaDon).font(.system(size: 14, weight: .bold))
                            Text(formatUtcShort(item.ngayNo)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTien(item.thanhTien)).font(.system(size: 14, weight: .bold))
                            if item.conLai > 0 {
                                Text("Còn nợ: \(formatTien(item.conLai))").font(.system(size: 11)).foregroundColor(Theme.danger)
                            } else {
                                Text("Đã trả hết").font(.system(size: 11)).foregroundColor(Theme.success)
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Lịch sử Công nợ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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
