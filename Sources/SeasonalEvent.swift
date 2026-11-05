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

    /// Emoji rải TĨNH (không rơi) làm hoạ tiết nền — xem SeasonalBackgroundPattern. Khác
    /// leading/trailingEmoji (dùng cho banner, 1 biểu tượng/bên).
    var patternSymbol: String {
        switch self {
        case .tet: return "🌸"
        case .valentine: return "💕"
        case .noel: return "❄️"
        case .quocKhanh, .thongNhat: return "⭐"
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

/// Nền trang trí dịp lễ — Theme.bg (tint màu phẳng) + rải thêm vài emoji mờ ở vị trí CỐ ĐỊNH (Canvas
/// vẽ 1 lần, KHÔNG TimelineView/animation — không phải hạt rơi) để rõ "không khí lễ" hơn hẳn chỉ tint
/// màu nhạt. nil (không dịp nào) thì chỉ là Theme.bg phẳng như cũ, không vẽ gì thêm. Dùng thay
/// Theme.bg trần ở các màn hình "nền chính" (cardListBackground, VoucherCuaToiView, UuDaiView...).
struct SeasonalBackgroundPattern: View {
    var body: some View {
        Theme.bg.overlay {
            if let theme = SeasonalEvent.active {
                Canvas { context, size in
                    var seed: UInt64 = 1_442_695_040
                    func rand() -> CGFloat {
                        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                        return CGFloat(seed >> 33) / CGFloat(1 << 31)
                    }
                    context.opacity = 0.16
                    for _ in 0..<22 {
                        let x = rand() * size.width
                        let y = rand() * size.height
                        let fontSize: CGFloat = 14 + rand() * 16
                        let resolved = context.resolve(Text(theme.patternSymbol).font(.system(size: fontSize)))
                        context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
                    }
                }
            }
        }
    }
}
