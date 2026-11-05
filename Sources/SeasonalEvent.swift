import SwiftUI

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
        case .tet: return Color(red: 0.93, green: 0.65, blue: 0.1)
        case .valentine: return Color(red: 0.98, green: 0.55, blue: 0.65)
        case .noel: return Color(red: 0.12, green: 0.47, blue: 0.24)
        case .quocKhanh, .thongNhat: return Color(red: 0.55, green: 0.04, blue: 0.06)
        }
    }

    /// Vài emoji rải TĨNH (không rơi) làm hoạ tiết nền kiểu "giấy gói quà" — xem
    /// SeasonalBackgroundPattern. Khác leading/trailingEmoji (dùng cho banner, 1 biểu tượng/bên).
    var patternSymbols: [String] {
        switch self {
        case .tet: return ["🌸", "🧧", "🏮"]
        case .valentine: return ["💕", "💘", "🌹"]
        case .noel: return ["❄️", "🎄", "🎁"]
        case .quocKhanh, .thongNhat: return ["⭐", "🇻🇳"]
        }
    }

    /// Màu nền BÃO HOÀ RÕ (không phải pastel nhạt) phủ TOÀN MÀN hình phía sau các card trắng — khớp
    /// phong cách tham khảo user gửi 2026-11-05 (nền đỏ/xanh lá đậm thật, card/nội dung trắng nổi lên
    /// trên, không phải nền trắng ám màu nhẹ). Đậm hơn hẳn washColors bản cũ (pastel ~90-100% sáng).
    var washColors: [Color] {
        switch self {
        case .tet: return [Color(red: 0.85, green: 0.18, blue: 0.14), Color(red: 0.95, green: 0.55, blue: 0.10)]
        case .valentine: return [Color(red: 0.90, green: 0.35, blue: 0.55), Color(red: 0.97, green: 0.62, blue: 0.70)]
        case .noel: return [Color(red: 0.73, green: 0.09, blue: 0.13), Color(red: 0.12, green: 0.47, blue: 0.24)]
        case .quocKhanh, .thongNhat: return [Color(red: 0.80, green: 0.08, blue: 0.1), Color(red: 0.55, green: 0.04, blue: 0.06)]
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
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
    }
}

/// Nền trang trí dịp lễ kiểu "giấy gói quà" — gradient bão hoà (washColors) PHỦ KÍN màn hình + lưới
/// emoji rải dày đặc, vị trí CỐ ĐỊNH (Canvas vẽ 1 lần, KHÔNG TimelineView/animation — không phải hạt
/// rơi, user đã yêu cầu bỏ hiệu ứng rơi). nil (không dịp nào) thì chỉ là Theme.bg phẳng như cũ.
/// Feedback 2026-11-05 "sao ko thấy background giáng sinh hẳn luôn" sau 2 lần tint nhẹ không đủ —
/// đổi hẳn sang màu nền thật + hoạ tiết rõ mắt thay vì chỉ tint %.
struct SeasonalBackgroundPattern: View {
    var body: some View {
        if let theme = SeasonalEvent.active {
            LinearGradient(colors: theme.washColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Canvas { context, size in
                        var seed: UInt64 = 1_442_695_040
                        func rand() -> CGFloat {
                            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                            return CGFloat(seed >> 33) / CGFloat(1 << 31)
                        }
                        let symbols = theme.patternSymbols
                        // Lưới thô (không random thuần) + jitter nhẹ mỗi ô — đều khắp màn hình kiểu hoạ
                        // tiết giấy gói, không tụ/thưa chỗ như random thuần với mật độ thấp.
                        let cols = 5, rows = 9
                        let cellW = size.width / CGFloat(cols)
                        let cellH = size.height / CGFloat(rows)
                        context.opacity = 0.30
                        for row in 0..<rows {
                            for col in 0..<cols {
                                let jitterX = (rand() - 0.5) * cellW * 0.5
                                let jitterY = (rand() - 0.5) * cellH * 0.5
                                let x = (CGFloat(col) + 0.5) * cellW + jitterX
                                let y = (CGFloat(row) + 0.5) * cellH + jitterY
                                let symbol = symbols[Int(rand() * CGFloat(symbols.count)) % symbols.count]
                                let fontSize: CGFloat = 20 + rand() * 14
                                let rotation = Angle(degrees: Double(rand() * 40 - 20))
                                let resolved = context.resolve(Text(symbol).font(.system(size: fontSize)))
                                var rotated = context
                                rotated.translateBy(x: x, y: y)
                                rotated.rotate(by: rotation)
                                rotated.draw(resolved, at: .zero, anchor: .center)
                            }
                        }
                    }
                }
        } else {
            Theme.bg
        }
    }
}
