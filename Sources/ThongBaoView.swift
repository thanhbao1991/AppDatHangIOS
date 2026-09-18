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
    f.dateFormat = "HH:mm dd-MM-yyyy"
    f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
    return f
}()

/// "Hôm nay, HH:mm" / "Hôm qua, HH:mm" / "HH:mm dd-MM-yyyy" — khớp kiểu Shopee đang hiện ở tab
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
                    List(items) { item in
                        Button {
                            if item.hoaDonId != nil {
                                selectedTab = .donHang
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.loai == .khuyenMai ? "🎁" : "📦")
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
                    }
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
            UserDefaults.standard.set(first.ngayTao, forKey: "thongBaoLastSeen")
        }
        loading = false
    }
}
