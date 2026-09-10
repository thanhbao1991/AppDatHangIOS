import SwiftUI

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
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                    Text(item.ngayTao).font(.system(size: 11)).foregroundColor(Theme.textFaint)
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
