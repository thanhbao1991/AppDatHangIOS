import SwiftUI

/// Server trả DateTime KHÔNG kèm timezone offset (System.Text.Json serialize DateTime "local" y
/// nguyên giờ VietnamTime.Now, xem ThongBaoService) — parse như giờ VN thẳng, không quy đổi UTC.
private let ngayTaoParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()
private let ngayTaoGioFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
    return f
}()
private let ngayTaoNgayThangFormatter: DateFormatter = {
    let f = DateFormatter()
    // Bỏ năm + đổi "-" thành "/" (2026-10-04, feedback: ngày tháng dạng "4/10" gọn hơn "04-10-2026",
    // năm hầu như luôn là năm hiện tại nên không cần hiện).
    f.dateFormat = "HH:mm d/M"
    f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
    return f
}()

/// "Hôm nay, HH:mm" / "Hôm qua, HH:mm" / "HH:mm d/M" — khớp kiểu Shopee đang hiện ở tab
/// Thông báo (2026-09-15), gọn hơn ISO thô server trả về.
func formatThongBaoTime(_ raw: String) -> String {
    // Chuỗi ISO đôi khi có phần .microseconds (vd "...T00:00:00.0000000") — cắt bỏ trước khi parse
    // vì ngayTaoParser không có "SSSSSSS".
    let truncated = String(raw.prefix(19))
    guard let date = ngayTaoParser.date(from: truncated) else { return raw }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
    if cal.isDateInToday(date) {
        return "Hôm nay, \(ngayTaoGioFormatter.string(from: date))"
    } else if cal.isDateInYesterday(date) {
        return "Hôm qua, \(ngayTaoGioFormatter.string(from: date))"
    }
    return ngayTaoNgayThangFormatter.string(from: date)
}

/// Icon riêng theo từng mốc tiến trình đơn hàng (feedback 2026-09-28: "📦" dùng chung cho cả 3 mốc
/// nhìn không phân biệt được) — khớp đúng 3 chuỗi Tieude cố định server sinh ra (xem
/// ThongBaoService.cs, DonHang chỉ có đúng 3 mốc: xác nhận/đang giao/hoàn tất, không có mốc huỷ).
/// Fallback "📦" cho tiêu đề lạ không khớp (phòng khi server đổi chuỗi mà quên cập nhật app).
private func thongBaoDonHangIcon(_ tieude: String) -> String {
    if tieude.contains("xác nhận") { return "📝" }
    if tieude.contains("đang được giao") { return "🚚" }
    if tieude.contains("hoàn tất") { return "🎉" }
    return "📦"
}

/// Port từ ThongBaoScreen.tsx — poll khi mở tab, đánh dấu mốc đã xem để MainTabView tính badge.
struct ThongBaoView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.dismiss) private var dismiss

    @State private var items: [ThongBao] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Thông báo", trailing: AnyView(
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundColor(.white)
                }
            ))

            Group {
                if loading {
                    fullScreenLoading()
                } else if items.isEmpty {
                    Text("Chưa có thông báo nào.").foregroundColor(Theme.textFaint).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Đổi sang dạng PHẲNG (2026-09-28, khớp OrderStatusView/LichSuViView) — bỏ
                    // listStyle mặc định (bo góc/card kiểu insetGrouped), dùng .plain + đường kẻ
                    // ngang mặc định giữa các dòng thay cho card riêng biệt.
                    List(items) { item in
                        Button {
                            if item.hoaDonId != nil {
                                selectedTab = .donHang
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.loai == .khuyenMai ? "🎁" : thongBaoDonHangIcon(item.tieude))
                                    .frame(width: 40, height: 40)
                                    .background(item.loai == .khuyenMai ? Color(red: 1, green: 0.953, blue: 0.878) : Theme.primaryTint)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.tieude).font(.system(size: 14, weight: .bold))
                                    Text(item.noiDung).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                                    Text(formatThongBaoTime(item.ngayTao)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                    .refreshable { await load(silent: true) }
                }
            }
        }
        .task { await load() }
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true }
        items = await APIClient.shared.getThongBao()
        if let first = items.first {
            Prefs.thongBaoLastSeen = first.ngayTao
        }
        loading = false
    }
}
