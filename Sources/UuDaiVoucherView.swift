import SwiftUI

/// Tab "Ưu đãi" gộp Ưu đãi (điểm danh, hộp quà, Xu) + Voucher của tôi — trước là 2 tab riêng, tab bar 6
/// nút quá chật (feedback so sánh với Katinat/The Coffee House, 5 tab). Một thanh tiêu đề chung,
/// bên dưới là bộ chọn 2 ngăn.
struct UuDaiVoucherView: View {
    var notificationBell: AnyView

    private enum Ngan: String, CaseIterable, Identifiable {
        case uuDai = "Ưu đãi"
        case voucher = "Voucher"
        var id: String { rawValue }
    }

    @State private var ngan: Ngan = .uuDai

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Ưu đãi", icon: "gift", centerTitle: true, trailing: notificationBell)

            Picker("", selection: $ngan) {
                ForEach(Ngan.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch ngan {
            case .uuDai: UuDaiView(notificationBell: notificationBell, showHeader: false)
            case .voucher: VoucherCuaToiView(notificationBell: notificationBell, showHeader: false)
            }
        }
        .background(Color(.systemBackground))
    }
}
