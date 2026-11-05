import SwiftUI
import UIKit

/// Màu/emoji trang trí theo dịp lễ — khoá theo Ma của voucher lễ tết tương ứng ở Backend (tập cố
/// định NOEL/VALENTINE/TETAL/QUOCKHANH/GIAIPHONG, xem DatHangService.MaDipLeTrangTri). Thêm dịp mới
/// thì thêm Ma vào Backend VÀ 1 case màu ở đây — câu chúc (title/subtitle) KHÔNG nằm ở đây, luôn lấy
/// thẳng ten/moTa của voucher qua SeasonalEvent (1 nguồn duy nhất, sửa ở AppQuanLyIOS là tự đổi).
enum SeasonalTheme: CaseIterable, Equatable {
    case noel, valentine, tet, quocKhanh, thongNhat

    init?(ma: String) {
        switch ma {
        case "NOEL": self = .noel
        case "VALENTINE": self = .valentine
        case "TETAL": self = .tet
        case "QUOCKHANH": self = .quocKhanh
        case "GIAIPHONG": self = .thongNhat
        default: return nil
        }
    }

    var leadingEmoji: String {
        switch self {
        case .tet: return "🧧"
        case .valentine: return "💘"
        case .noel: return "🎄"
        case .quocKhanh, .thongNhat: return "🇻🇳"
        }
    }

    var trailingEmoji: String {
        switch self {
        case .tet: return "🌸"
        case .valentine: return "💖"
        case .noel: return "❄️"
        case .quocKhanh, .thongNhat: return "⭐"
        }
    }

    /// Màu CHỦ ĐẠO tạm thời ghi đè Theme.primary/primaryDark (nav bar, nút CTA, tab đang chọn...)
    /// suốt những ngày dịp lễ diễn ra — chủ quán đồng ý đè cả màu hạng cho những ngày này (2026-11-05).
    /// primary/primaryDark CỐ Ý luôn CÙNG 1 TÔNG MÀU (chỉ khác độ sáng/tối), KHÔNG pha 2 màu bổ sung
    /// khác hẳn nhau (vd đỏ+xanh lá) — bài học 2026-11-05: gradient đỏ→xanh lá trải dài toàn màn hình
    /// cho ra khoảng giữa xám/nâu bẩn (2 màu bổ sung luôn trộn ra màu trung tính khi gradient đủ dài),
    /// hỏng hết. Xanh lá/vàng... của dịp đó chỉ xuất hiện qua emoji (leadingEmoji/trailingEmoji), KHÔNG
    /// còn trộn vào nền.
    var primary: Color {
        switch self {
        case .tet: return Color(red: 0.80, green: 0.08, blue: 0.1)
        case .valentine: return Color(red: 0.87, green: 0.18, blue: 0.42)
        case .noel: return Color(red: 0.73, green: 0.09, blue: 0.13)
        case .quocKhanh, .thongNhat: return Color(red: 0.80, green: 0.08, blue: 0.1)
        }
    }

    var primaryDark: Color {
        switch self {
        case .tet: return Color(red: 0.50, green: 0.04, blue: 0.06)
        case .valentine: return Color(red: 0.55, green: 0.09, blue: 0.26)
        case .noel: return Color(red: 0.45, green: 0.04, blue: 0.07)
        case .quocKhanh, .thongNhat: return Color(red: 0.50, green: 0.04, blue: 0.06)
        }
    }

    /// Vài emoji rải mờ trong banner (seasonalBanner) và header (SeasonalHeaderScatter).
    var patternSymbols: [String] {
        switch self {
        case .tet: return ["🌸", "🧧", "🏮"]
        case .valentine: return ["💕", "💘", "🌹"]
        case .noel: return ["❄️", "🎄", "🎁"]
        case .quocKhanh, .thongNhat: return ["⭐", "🇻🇳"]
        }
    }

    /// Tên App Icon thay thế khớp AppIcon-*.appiconset trong Assets.xcassets (xem AppIconSwitcher) —
    /// nil = CHƯA có ảnh icon riêng cho dịp này (vd Quốc khánh/30-4-1-5, user nói "thêm sau"), app
    /// vẫn dùng icon mặc định, không lỗi gì. Cập nhật khi có thêm ảnh: thêm appiconset mới, khai ở
    /// project.yml (CFBundleAlternateIcons) RỒI mới trả tên ở đây.
    var alternateIconName: String? {
        switch self {
        case .noel: return "AppIcon-Noel"
        case .valentine: return "AppIcon-Valentine"
        case .tet: return "AppIcon-Tet"
        case .quocKhanh, .thongNhat: return nil
        }
    }

    #if DEV_LOGIN
    /// Câu chúc MẪU chỉ dùng khi bấm "🧪 Xem trước" (chưa có voucher thật đang hiệu lực để lấy
    /// ten/moTa) — khớp đúng chữ đang lưu ở voucher tương ứng (Ma ở trên) tại thời điểm viết, sửa ở
    /// AppQuanLyIOS không tự đổi được bản xem trước này (chỉ ảnh hưởng câu chúc THẬT ngoài preview).
    var previewTen: String {
        switch self {
        case .tet: return "Tết Nguyên Đán"
        case .valentine: return "Valentine"
        case .noel: return "Giáng sinh"
        case .quocKhanh: return "Quốc khánh 2/9"
        case .thongNhat: return "30/4 - 1/5"
        }
    }
    var previewMoTa: String {
        "🧪 Xem trước — Giảm 10%, tối đa 10.000đ nhân dịp \(previewTen)"
    }
    #endif
}

/// Dịp lễ đang hiệu lực — nạp từ Backend (DipLe, xem APIClient.getDipLe) chứ KHÔNG tự tính ngày ở
/// client (trước 2026-11-05 từng tự tính, dễ lệch ngày với voucher giảm giá thật dùng cùng dịp).
/// Theo pattern "static var + NotificationCenter" đã có ở Prefs.swift (hangColors đổi theo hạng) vì
/// các View đọc qua computed static var, không phải @Published — cần tick/.onReceive(.christmasPreviewToggled)
/// ở call site để buộc body vẽ lại.
enum SeasonalEvent {
    private(set) static var dipLe: DipLe?
    private(set) static var theme: SeasonalTheme?

    #if DEV_LOGIN
    /// Công tắc xem thử — CHỈ có ở bản dev (DEV_LOGIN), bật ở SettingsView khu "🧪 Xem trước...".
    /// nil = không ghi đè (dùng dữ liệu thật từ Backend).
    static var previewOverride: SeasonalTheme?
    #endif

    static var active: SeasonalTheme? {
        #if DEV_LOGIN
        if let previewOverride { return previewOverride }
        #endif
        return theme
    }

    static var bannerTitle: String {
        #if DEV_LOGIN
        if let previewOverride { return previewOverride.previewTen }
        #endif
        return dipLe?.ten ?? ""
    }

    static var bannerSubtitle: String {
        #if DEV_LOGIN
        if let previewOverride { return previewOverride.previewMoTa }
        #endif
        return dipLe?.moTa ?? ""
    }

    /// Tải dịp lễ từ Backend — gọi lúc khởi động app (AppDatHangIOSApp) và mỗi lần mở lại tab Thực
    /// đơn (MenuView.task, khớp cách getBanChayIds tự refresh). applyNavBarAppearance lại vì nav bar
    /// là UIKit thuần, không tự vẽ lại theo SwiftUI diffing như Theme.primary ở các View khác.
    @MainActor
    static func load() async {
        let dipLe = await APIClient.shared.getDipLe()
        self.dipLe = dipLe
        theme = dipLe.flatMap { SeasonalTheme(ma: $0.ma) }
        Theme.applyNavBarAppearance()
        AppIconSwitcher.apply(active)
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
    }
}

/// Đổi App Icon trên màn hình chính theo dịp lễ (UIApplication.setAlternateIconName) — nil (không
/// dịp nào, hoặc dịp chưa có ảnh icon riêng) thì quay về icon mặc định. Gọi từ SeasonalEvent.load()
/// nên tự chạy cùng lúc với banner/màu, không cần gọi tay chỗ khác.
enum AppIconSwitcher {
    @MainActor
    static func apply(_ theme: SeasonalTheme?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let targetName = theme?.alternateIconName
        guard UIApplication.shared.alternateIconName != targetName else { return }
        UIApplication.shared.setAlternateIconName(targetName) { error in
            // Lỗi hiếm (vd icon không có trong bundle do thiếu ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS)
            // — không phải lỗi nghiêm trọng, app vẫn chạy bình thường với icon cũ, chỉ log để biết mà sửa.
            if let error { print("[AppIconSwitcher] setAlternateIconName(\(targetName ?? "nil")) lỗi: \(error)") }
        }
    }
}

// Hệ thống trang trí dịp lễ (làm lại lần cuối 2026-11-05 sau 3 vòng bị chê "toàn trắng" → "xám bẩn"
// → "rời rạc"): KHÔNG tô màu thân từng màn nữa (mỗi màn cấu trúc khác nhau — card/List phẳng/khoảng
// trống — tô thân màn ra mỗi chỗ 1 kiểu, khối đỏ lớn, ô màu chồng ô màu → rời rạc). Chất lễ hội dồn vào
// đúng những thứ MỌI MÀN dùng chung nên tự đồng bộ:
//   1. Header (HeaderBackground — SearchBar/TitleBar/header Tài khoản): màu dịp + dây trang trí treo dọc
//      mép dưới (SeasonalGarland) + vài hoạ tiết mờ.
//   2. Màu chủ đạo (Theme.primary): nút CTA, giá, tab đang chọn, thẻ hạng.
//   3. Theme.bg (nền sau card) đổi sang tông kem ấm (surface) — nhẹ, đồng nhất.
//   4. Banner dịp lễ ở tab Thực đơn + App Icon.

extension SeasonalTheme {
    /// Nền sau card (thay xám #F5F5F5 của Theme.bg) — màu ĐỤC sáng ấm, không phải primary.opacity(...)
    /// (alpha chồng lên nền khác nhau ở mỗi màn ra mỗi chỗ 1 màu khác nhau).
    var surface: Color {
        switch self {
        case .tet: return Color(red: 1.0, green: 0.97, blue: 0.90)
        case .valentine: return Color(red: 1.0, green: 0.945, blue: 0.955)
        case .noel, .quocKhanh, .thongNhat: return Color(red: 1.0, green: 0.962, blue: 0.94)
        }
    }

    var garlandWire: Color {
        switch self {
        case .noel: return Color(red: 0.13, green: 0.33, blue: 0.18)
        case .tet: return Color(red: 0.93, green: 0.74, blue: 0.32)
        case .valentine: return Color.white.opacity(0.75)
        case .quocKhanh, .thongNhat: return Color(red: 1.0, green: 0.86, blue: 0.3).opacity(0.8)
        }
    }
}

/// Nền header dùng chung cho MỌI tab — gradient màu chủ đạo, dịp lễ thì thêm hoạ tiết mờ + dây trang
/// trí ở mép dưới. Header phải cộng thêm SeasonalGarland.extraBottom vào padding dưới để dây nằm GỌN
/// trong header, không đè lên nội dung bên dưới.
struct HeaderBackground: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.primaryGradient.ignoresSafeArea(edges: .top)
            if let theme = SeasonalEvent.active {
                SeasonalHeaderScatter(theme: theme).ignoresSafeArea(edges: .top)
                SeasonalGarland(theme: theme).frame(height: SeasonalGarland.height)
            }
        }
    }
}

/// Vài biểu tượng dịp lễ mờ rải trong header (vị trí cố định theo seed, không chuyển động).
private struct SeasonalHeaderScatter: View {
    let theme: SeasonalTheme

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 2_024
            func rand() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat(seed >> 33) / CGFloat(1 << 31)
            }
            let symbols = theme.patternSymbols
            let count = 6
            context.opacity = 0.16
            for i in 0..<count {
                // Chia đều theo chiều ngang rồi lệch nhẹ — không dồn cụm 1 bên.
                let x = (CGFloat(i) + 0.2 + rand() * 0.6) * size.width / CGFloat(count)
                let y = size.height * (0.15 + rand() * 0.55)
                let resolved = context.resolve(Text(symbols[i % symbols.count]).font(.system(size: 16 + rand() * 10)))
                context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Dây trang trí võng dọc mép dưới header: Noel = dây đèn nhiều màu phát sáng, Tết = đèn lồng + hoa
/// mai, Valentine = tim, 2/9 & 30/4 = cờ đuôi nheo vàng. Vẽ bằng Canvas 1 lần, không chuyển động.
struct SeasonalGarland: View {
    static let height: CGFloat = 24
    /// Cộng vào padding dưới của header khi đang dịp lễ — 0 ngoài dịp để header giữ nguyên chiều cao cũ.
    static var extraBottom: CGFloat { SeasonalEvent.active == nil ? 0 : height - 4 }

    let theme: SeasonalTheme

    private static let bulbColors: [Color] = [
        Color(red: 1.0, green: 0.84, blue: 0.30),
        Color(red: 0.40, green: 0.85, blue: 0.45),
        Color(red: 0.45, green: 0.78, blue: 1.0),
        Color(red: 1.0, green: 0.97, blue: 0.85),
    ]

    var body: some View {
        Canvas { context, size in
            let swags = max(4, Int((size.width / 72).rounded()))
            let swagW = size.width / CGFloat(swags)
            let topY: CGFloat = 2
            let sag: CGFloat = 16 // điểm điều khiển — độ võng thật ~ sag/2

            var wire = Path()
            for i in 0..<swags {
                let x0 = CGFloat(i) * swagW
                wire.move(to: CGPoint(x: x0, y: topY))
                wire.addQuadCurve(to: CGPoint(x: x0 + swagW, y: topY),
                                  control: CGPoint(x: x0 + swagW / 2, y: topY + sag))
            }
            context.stroke(wire, with: .color(theme.garlandWire), lineWidth: 1.3)

            var index = 0
            for i in 0..<swags {
                let x0 = CGFloat(i) * swagW
                for t in [0.2, 0.5, 0.8] as [CGFloat] {
                    let mt = 1 - t
                    let x = mt * mt * x0 + 2 * mt * t * (x0 + swagW / 2) + t * t * (x0 + swagW)
                    let y = mt * mt * topY + 2 * mt * t * (topY + sag) + t * t * topY
                    drawItem(in: context, at: CGPoint(x: x, y: y), index: index)
                    index += 1
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawItem(in context: GraphicsContext, at p: CGPoint, index: Int) {
        switch theme {
        case .noel:
            let color = Self.bulbColors[index % Self.bulbColors.count]
            // Quầng sáng mờ phía sau bóng đèn
            context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 1, width: 12, height: 14)),
                         with: .color(color.opacity(0.35)))
            context.fill(Path(CGRect(x: p.x - 1.5, y: p.y - 1, width: 3, height: 3)),
                         with: .color(Color(red: 0.12, green: 0.2, blue: 0.14)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y + 1.5, width: 6, height: 9)),
                         with: .color(color))
        case .quocKhanh, .thongNhat:
            var flag = Path()
            flag.move(to: CGPoint(x: p.x - 5, y: p.y))
            flag.addLine(to: CGPoint(x: p.x + 5, y: p.y))
            flag.addLine(to: CGPoint(x: p.x, y: p.y + 10))
            flag.closeSubpath()
            context.fill(flag, with: .color(index % 2 == 0 ? Color(red: 1.0, green: 0.85, blue: 0.2) : .white))
        case .tet, .valentine:
            let symbols = theme == .tet ? ["🏮", "🌼"] : ["🤍", "💖"]
            let resolved = context.resolve(Text(symbols[index % symbols.count]).font(.system(size: 11)))
            context.draw(resolved, at: CGPoint(x: p.x, y: p.y - 1), anchor: .top)
        }
    }
}
