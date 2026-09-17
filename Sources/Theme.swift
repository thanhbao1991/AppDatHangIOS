import SwiftUI

/// Port từ src/theme.ts (bản RN cũ) — xanh navy chuyên nghiệp, khớp tông AppShippingIOS/AppQuanLyIOS.
/// Từ 2026-09-16: primary/primaryDark đổi màu theo KhachHangSession.shared.hang (2026-09-16) — để
/// khách lên hạng Bạc/Vàng/Kim Cương thấy app "sang" hơn hẳn ngay khi mở app, không chỉ ở badge nhỏ
/// trong tab Tài khoản. "Thành Viên" (chưa đạt hạng) giữ nguyên đúng tông navy cũ.
enum Theme {
    /// Cặp màu (sáng, tối) từng hạng — dùng cho cả Theme.primary/primaryDark (toàn app) lẫn gradient
    /// thẻ hạng ở SettingsView (gom về đây để không lệch màu giữa 2 nơi).
    // Lịch sử đổi tông: Bạc/Kim Cương bản đầu (xám ám nâu + xanh rêu đục) bị chê "sai tông". Kim
    // Cương thử tím amethyst rồi đổi hẳn sang đen thẻ ngân hàng theo yêu cầu. 2026-09-17: sau khi
    // xem 4 hạng cạnh nhau, tinh chỉnh theo review chi tiết — giữ nguyên Kim Cương (đen/xám đen,
    // được chấm "tốt nhất") + Thành Viên (navy, "khá ổn"), CHỈ đổi Bạc (xám ghi "tối/xỉn" → xám thép
    // sáng hơn có ánh xanh) và Vàng (nâu vàng "tương phản không cao" → vàng kim/gold đậm rõ ràng
    // hơn) theo đúng mã hex được duyệt.
    static let hangColors: [String: (primary: Color, dark: Color)] = [
        // Giãn khoảng cách 2 đầu (trước #1C1D21→#303136 quá gần nhau, gradient nhìn gần như solid) —
        // primary gần đen tuyền, dark kéo lên xám đậm rõ rệt hơn để thấy rõ hiệu ứng gradient.
        "Kim Cương": (hex(0x0A, 0x0A, 0x0D), hex(0x45, 0x47, 0x4E)),
        "Vàng": (hex(0xB7, 0x79, 0x1F), hex(0x74, 0x42, 0x10)),
        "Bạc": (hex(0x4A, 0x55, 0x68), hex(0x2D, 0x37, 0x48)),
        "Thành Viên": (hex(0x1E, 0x4E, 0x8C), hex(0x15, 0x35, 0x5F)),
    ]
    private static func hex(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
    static var primary: Color { hangColors[KhachHangSession.shared.hang]?.primary ?? hangColors["Thành Viên"]!.primary }
    static var primaryDark: Color { hangColors[KhachHangSession.shared.hang]?.dark ?? hangColors["Thành Viên"]!.dark }
    /// Trước là hex cố định #EAF1FA (navy nhạt) — giờ tính theo primary hiện tại để lên tông tự động
    /// khi đổi hạng, xấp xỉ đúng độ nhạt của tông cũ khi hang == "Thành Viên" (opacity 0.12 trên nền trắng).
    static var primaryTint: Color { primary.opacity(0.12) }
    /// Gradient chéo sáng→tối — CÙNG công thức với card "Hạng thành viên" ở SettingsView (được khen
    /// "đẹp, không phẳng"). Dùng cho nút CTA chính + cuống voucher (VoucherTicketCard) thay vì nền
    /// đặc Theme.primary, để có cùng cảm giác "sang" ở mọi nơi nổi bật, không chỉ riêng 1 card.
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [primary, primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let success = Color(red: 0x2E / 255, green: 0x7D / 255, blue: 0x32 / 255)
    static let danger = Color(red: 0xC6 / 255, green: 0x28 / 255, blue: 0x28 / 255)
    static let warning = Color(red: 0xF9 / 255, green: 0xA8 / 255, blue: 0x25 / 255)
    static let textMuted = Color(red: 0x66 / 255, green: 0x66 / 255, blue: 0x66 / 255)
    static let textFaint = Color(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255)
    static let divider = Color(red: 0xEE / 255, green: 0xEE / 255, blue: 0xEE / 255)
    static let bg = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF5 / 255)

    /// Emoji dự phòng cho từng nhóm — dùng khi món chưa có ảnh thật (MenuView.productRow,
    /// CheckoutView.itemThumbnail). Gom về đây (trước ở riêng MenuView) để CheckoutView dùng chung
    /// được, không phải tách bản riêng. Chọn theo đúng nghĩa đồ uống của từng nhóm.
    static let nhomIcons: [String: String] = [
        "Ăn Vặt": "🥫",
        "Bạc Xỉu": "🥃",
        "Ca Cao": "🧉",
        "Cà Phê": "☕",
        "Đá Xay": "🍧",
        "Khác": "🥫",
        "Latte": "🍶",
        "Nước Ép": "🍊",
        "Nước Lon": "🥫",
        "Sinh Tố": "🍓",
        "Soda": "🥤",
        "Sữa Chua": "🥣",
        "Sữa Tươi": "🥛",
        "Thuốc lá": "🥫",
        "Trà": "🍃",
        "Trà Hiện Đại": "🍹",
        "Trà Sữa": "🧋",
        "Trà Truyền Thống": "🍵",
        "Yêu thích": "❤️",
    ]
    static let defaultNhomIcon = "🥤"

    /// Set UINavigationBar.appearance() theo Theme.primary hiện tại — tách khỏi AppDatHangIOSApp.init()
    /// để gọi lại được mỗi khi KhachHangSession đổi hạng (không chỉ lúc khởi động app). Proxy UIAppearance
    /// chỉ ăn cho bar tạo MỚI nên còn phải tự tay áp lại cho các UINavigationController ĐANG hiển thị.
    static func applyNavBarAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        // UINavigationBarAppearance không nhận LinearGradient thẳng — vẽ gradient ra UIImage rồi gán
        // backgroundImage, khớp hướng chéo (topLeading→bottomTrailing) với Theme.primaryGradient dùng
        // ở nút CTA/voucher/card hạng, để nav bar không còn là 1 mảng màu đặc lệch tông với phần còn lại.
        navAppearance.backgroundImage = gradientImage(top: UIColor(primary), bottom: UIColor(primaryDark))
        // .scaleToFill — mặc định backgroundImageContentMode có thể crop ảnh vuông theo tỉ lệ thanh
        // nav bar (rộng/lùn), ép kéo giãn full để gradient trải liền mạch, không bị cắt méo.
        navAppearance.backgroundImageContentMode = .scaleToFill
        navAppearance.backgroundColor = UIColor(primary)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        let backItemAppearance = UIBarButtonItemAppearance()
        backItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.backButtonAppearance = backItemAppearance

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                applyNavBarAppearance(to: window.rootViewController, appearance: navAppearance)
            }
        }
    }

    /// Vẽ gradient chéo (trái trên → phải dưới, khớp Theme.primaryGradient) ra 1 UIImage nhỏ (44x44 —
    /// UINavigationBarAppearance.backgroundImage tự stretch ra full chiều rộng/cao thanh nav bar,
    /// không cần vẽ đúng kích thước thật) để gán vào backgroundImage.
    private static func gradientImage(top: UIColor, bottom: UIColor) -> UIImage {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    private static func applyNavBarAppearance(to viewController: UIViewController?, appearance: UINavigationBarAppearance) {
        guard let viewController else { return }
        if let nav = viewController as? UINavigationController {
            nav.navigationBar.standardAppearance = appearance
            nav.navigationBar.scrollEdgeAppearance = appearance
            nav.navigationBar.compactAppearance = appearance
            nav.navigationBar.tintColor = .white
        }
        for child in viewController.children {
            applyNavBarAppearance(to: child, appearance: appearance)
        }
        if let presented = viewController.presentedViewController {
            applyNavBarAppearance(to: presented, appearance: appearance)
        }
    }
}

/// Thay thế .buttonStyle(.borderedProminent).tint(Theme.primary) ở MỌI nút CTA chính trong app —
/// .borderedProminent là style hệ thống, tự vẽ nền PHẲNG theo .tint(), không nhận gradient được.
/// Cố tình KHÔNG tự đặt .frame ở đây: label truyền vào (Text/ProgressView) đã tự set .frame riêng
/// ở từng call site (vd .frame(maxWidth: .infinity) hay .frame(minWidth: 120)) — giữ nguyên layout
/// cũ, style này chỉ đổi CÁCH TÔ MÀU nền.
struct GradientProminentButtonStyle: ButtonStyle {
    /// true cho hành động phá hoại (vd "Xoá món") — KHÔNG theo màu hạng, giữ đỏ cảnh báo cố định
    /// bất kể khách đang hạng gì (Kim Cương đen, Vàng gold... đỏ luôn phải là đỏ để còn cảnh báo được).
    var danger: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    private var gradient: LinearGradient {
        danger
            ? LinearGradient(colors: [Theme.danger, Theme.danger.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
            : Theme.primaryGradient
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

extension ButtonStyle where Self == GradientProminentButtonStyle {
    /// Dùng như .buttonStyle(.gradientProminent) — khớp cú pháp .buttonStyle(.borderedProminent) cũ,
    /// đổi call site tối thiểu (chỉ bỏ .tint(Theme.primary) đi kèm, không cần đổi gì khác).
    static var gradientProminent: GradientProminentButtonStyle { GradientProminentButtonStyle() }
    static func gradientProminent(danger: Bool) -> GradientProminentButtonStyle { GradientProminentButtonStyle(danger: danger) }
}

extension View {
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
    // KHÔNG bọc bằng Section — List tự thêm khoảng cách ngầm giữa các Section (kể cả không có
    // header/footer), khiến đường nối dọc (đường kẻ nối các khoanh số bước) bị đứt đoạn ở ranh
    // giới giữa 2 card liền nhau dù mỗi card tự vẽ đường kẻ tràn hết chiều cao của nó.
    content()
        .listRowInsets(EdgeInsets(top: topExtra, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
}

/// "Mặc định"/"Size Chuẩn"/"Chuẩn" là biến thể mặc định — khớp cách AppQuanLyIOS ẩn hậu tố size khi
/// là size mặc định (chỉ hiện "(size)" khi khác size chuẩn). Dùng chung cho OrderDetailView và
/// CheckoutView thay vì mỗi chỗ tự viết lại 1 bản.
func bienTheSuffix(_ ten: String) -> String {
    ["", "Mặc định", "Size Chuẩn", "Chuẩn"].contains(ten) ? "" : " (\(ten))"
}

/// Khớp "Size L" và lỗi chính tả có thật "Soze L" trong menu — cùng pattern LIKE '%ze L%' bên Backend
/// (VoucherDieuKien.UpsizeMonMoi). Dùng chung MenuView (chip VIP) và CheckoutView (tính giảm giá
/// preview cho voucher UpsizeMonMoi) để không lệch nhau.
func isSizeLBienThe(_ tenBienThe: String) -> Bool {
    tenBienThe.range(of: "ze L", options: [.caseInsensitive, .diacriticInsensitive]) != nil
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

/// Viết tắt kiểu "5k" — khớp HoaDonFormatting.moneyShort bên AppQuanLyIOS, dùng cho phụ chú ngắn
/// (giá topping đi kèm tên) nơi không cần rõ số, chỉ cần ước lượng nhanh.
func formatTienShort(_ value: Double) -> String {
    "\(Int((value / 1000).rounded()))k"
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
