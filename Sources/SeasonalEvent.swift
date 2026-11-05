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

    /// Vài emoji dùng cho hoạ tiết rải trong banner (seasonalBanner) — KHÔNG còn dùng cho nền toàn màn
    /// (SeasonalBackgroundPattern bỏ hẳn lớp hoạ tiết sau khi làm lại 2026-11-05, xem comment ở đó).
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

/// Nền trang trí dịp lễ — gradient 2 sắc độ CÙNG TÔNG (primary → primaryDark, xem comment ở đó), ĐƠN
/// GIẢN, không hoạ tiết rải. Làm lại hoàn toàn 2026-11-05 sau khi bản "giấy gói quà" (gradient 2 tông
/// khác hẳn + lưới emoji dày) bị chê xám/bẩn + rối mắt ở MỌI màn hình — bài học: nền toàn màn hình
/// cao/rộng cần ĐƠN GIẢN (1 tông màu, không hoạ tiết) để không đè lên nội dung/card bên trên; hoạ tiết
/// phong phú chỉ còn ở banner (seasonalBanner, diện tích nhỏ, kiểm soát được). nil (không dịp nào) thì
/// vẫn Theme.bg phẳng xám trung tính như cũ.
struct SeasonalBackgroundPattern: View {
    var body: some View {
        if let theme = SeasonalEvent.active {
            LinearGradient(colors: [theme.primary, theme.primaryDark], startPoint: .top, endPoint: .bottom)
        } else {
            Theme.bg
        }
    }
}
