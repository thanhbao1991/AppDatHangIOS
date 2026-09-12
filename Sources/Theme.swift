import SwiftUI

/// Port từ src/theme.ts (bản RN cũ) — xanh navy chuyên nghiệp, khớp tông AppShippingIOS/AppQuanLyIOS.
enum Theme {
    static let primary = Color(red: 0x1E / 255, green: 0x4E / 255, blue: 0x8C / 255)
    static let primaryDark = Color(red: 0x15 / 255, green: 0x35 / 255, blue: 0x5F / 255)
    static let primaryTint = Color(red: 0xEA / 255, green: 0xF1 / 255, blue: 0xFA / 255)
    static let success = Color(red: 0x2E / 255, green: 0x7D / 255, blue: 0x32 / 255)
    static let danger = Color(red: 0xC6 / 255, green: 0x28 / 255, blue: 0x28 / 255)
    static let warning = Color(red: 0xF9 / 255, green: 0xA8 / 255, blue: 0x25 / 255)
    static let textMuted = Color(red: 0x66 / 255, green: 0x66 / 255, blue: 0x66 / 255)
    static let textFaint = Color(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255)
    static let divider = Color(red: 0xEE / 255, green: 0xEE / 255, blue: 0xEE / 255)
    static let bg = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF5 / 255)
}

extension View {
    /// Tô nền navbar brandPrimary + chữ trắng — khớp y hệt style AppQuanLyIOS đang lan ra toàn app
    /// (xem toolbarBackground(Color.brandPrimary...) lặp lại ở mọi navigationTitle bên đó).
    func brandNavBar() -> some View {
        self
            .toolbarBackground(Theme.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Style card trắng bo góc dùng chung cho MỌI tab (Giỏ hàng/Đơn hàng/Ưu đãi/Tài khoản) — trước
    /// đây mỗi màn tự định nghĩa card() riêng (padding/corner/border na ná nhau nhưng không giống
    /// hệt), giờ gom 1 chỗ để khoảng cách card-với-top và card-với-card đồng bộ thật sự trên cả 4 tab
    /// thay vì "trông giống giống" do trùng hợp copy-paste.
    func cardBoxStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
            .padding(.horizontal)
            .padding(.vertical, 6)
    }

    /// Nền xám Theme.bg thống nhất cho List(.plain) ở mọi tab card-based — .plain tự thân nền trắng,
    /// cần lật nền hệ thống mới lộ ra Theme.bg phía dưới để card trắng nổi lên.
    func cardListBackground() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
    }
}

@ViewBuilder
func cardBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10, content: content)
        .cardBoxStyle()
}

/// Bọc 1 card thành Section của List — topExtra CHỈ dùng cho card ĐẦU TIÊN của mỗi tab (thêm 6pt để
/// khoảng cách với TitleBar bằng đúng khoảng cách giữa 2 card liền nhau: 6pt padding riêng của mỗi
/// card cộng lại thành 12, còn card đầu chỉ có 6 từ chính nó nên thiếu 6pt so với các card sau).
@ViewBuilder
func cardRow<Content: View>(topExtra: CGFloat = 0, @ViewBuilder content: () -> Content) -> some View {
    Section { content() }
        .listRowInsets(EdgeInsets(top: topExtra, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
}

/// Chuẩn hoá chuỗi tiếng Việt để so khớp không dấu — dùng cho tìm kiếm món (MenuView) và gợi ý tên
/// đường khi nhập địa chỉ (CheckoutView). Gom về 1 chỗ thay vì mỗi màn tự viết lại 1 bản.
func normalizeVN(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
        .replacingOccurrences(of: "đ", with: "d", options: .caseInsensitive)
        .lowercased()
        .trimmingCharacters(in: .whitespaces)
}

func formatTien(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.maximumFractionDigits = 0
    let number = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    return "\(number)đ"
}

/// Số dư ví/giao dịch ví hiển thị dưới nhãn "Xu" thay vì "đ" — quy đổi 1 Xu = 1đ y hệt bên dưới
/// (dùng thẳng để trừ trực tiếp vào hoá đơn), CHỈ đổi tên hiển thị. Lý do: gắn số tiền thật (15.000đ)
/// kích hoạt "nỗi đau chi tiêu" khiến khách ngại tiêu/nạp hơn hẳn so với 1 đơn vị game-hoá (15.000
/// Xu) — quy ước phổ biến ở app thương mại/loyalty (Shopee, ShopeeFood, Baemin...). Đừng dùng cho
/// giá món/công nợ/hoá đơn — những cái đó vẫn phải hiện đúng "đ" là tiền thật.
func formatXu(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.maximumFractionDigits = 0
    let number = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    return "\(number) Xu"
}
