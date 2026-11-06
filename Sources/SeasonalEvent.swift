import SwiftUI
import UIKit

/// Màu/emoji trang trí theo dịp lễ — khoá theo Ma của voucher lễ tết tương ứng ở Backend (xem
/// DatHangService.MaDipLeTrangTri). Thêm dịp mới thì thêm Ma vào Backend VÀ 1 case ở đây — câu chúc
/// (title/subtitle) KHÔNG nằm ở đây, luôn lấy thẳng ten/moTa của voucher qua SeasonalEvent.
enum SeasonalTheme: CaseIterable, Equatable {
    case tetDuong, tet, valentine, quocTePhuNu, phuNuVietNam, gioTo, thongNhat, thieuNhi, doanNgo, thuongBinh, vuLan, quocKhanh, trungThu, nhaGiao, noel

    init?(ma: String) {
        switch ma {
        case "TETDUONG": self = .tetDuong
        case "TETAL": self = .tet
        case "VALENTINE": self = .valentine
        case "QTPHUNU": self = .quocTePhuNu
        case "PHUNUVN": self = .phuNuVietNam
        case "GIOTO": self = .gioTo
        case "DOANNGO": self = .doanNgo
        case "THUONGBINH": self = .thuongBinh
        case "VULAN": self = .vuLan
        case "GIAIPHONG": self = .thongNhat
        case "THIEUNHI": self = .thieuNhi
        case "QUOCKHANH": self = .quocKhanh
        case "TRUNGTHU": self = .trungThu
        case "NHAGIAO": self = .nhaGiao
        case "NOEL": self = .noel
        default: return nil
        }
    }

    var leadingEmoji: String {
        switch self {
        case .tetDuong: return "🎆"
        case .tet: return "🧧"
        case .valentine: return "💘"
        case .quocTePhuNu, .phuNuVietNam: return "💐"
        case .thieuNhi: return "🎈"
        case .quocKhanh, .thongNhat, .gioTo, .thuongBinh: return "🇻🇳"
        case .doanNgo: return "🍑"
        case .vuLan: return "🌹"
        case .trungThu: return "🏮"
        case .nhaGiao: return "📚"
        case .noel: return "🎄"
        }
    }

    var trailingEmoji: String {
        switch self {
        case .tetDuong: return "🥂"
        case .tet: return "🌸"
        case .valentine: return "💖"
        case .quocTePhuNu, .phuNuVietNam: return "🌷"
        case .gioTo: return "🌾"
        case .doanNgo: return "🍉"
        case .thuongBinh: return "🕯️"
        case .vuLan: return "🏮"
        case .thieuNhi: return "🧸"
        case .quocKhanh, .thongNhat: return "⭐"
        case .trungThu: return "🌕"
        case .nhaGiao: return "💐"
        case .noel: return "❄️"
        }
    }

    /// Màu CHỦ ĐẠO tạm thời ghi đè Theme.primary/primaryDark (nav bar, nút CTA, tab đang chọn...)
    /// suốt những ngày dịp lễ diễn ra — chủ quán đồng ý đè cả màu hạng cho những ngày này (2026-11-05).
    /// primary/primaryDark CỐ Ý luôn CÙNG 1 TÔNG MÀU (chỉ khác độ sáng/tối), KHÔNG pha 2 màu bổ sung
    /// khác hẳn nhau (vd đỏ+xanh lá) — bài học 2026-11-05: gradient đỏ→xanh lá trải dài toàn màn hình
    /// cho ra khoảng giữa xám/nâu bẩn (2 màu bổ sung luôn trộn ra màu trung tính khi gradient đủ dài),
    /// hỏng hết. Xanh lá/vàng... của dịp đó chỉ xuất hiện qua emoji (leadingEmoji/trailingEmoji), KHÔNG
    /// còn trộn vào nền.
    /// Màu đủ đậm để chữ trắng trên header/nút CTA đọc rõ.
    var primary: Color {
        switch self {
        case .tetDuong: return Color(red: 0.30, green: 0.24, blue: 0.62)
        case .tet, .quocKhanh, .thongNhat: return Color(red: 0.80, green: 0.08, blue: 0.1)
        case .valentine: return Color(red: 0.87, green: 0.18, blue: 0.42)
        case .quocTePhuNu, .phuNuVietNam: return Color(red: 0.66, green: 0.24, blue: 0.62)
        case .gioTo, .thuongBinh: return Color(red: 0.62, green: 0.13, blue: 0.08)
        case .doanNgo: return Color(red: 0.13, green: 0.48, blue: 0.25)
        case .vuLan: return Color(red: 0.60, green: 0.16, blue: 0.30)
        case .thieuNhi: return Color(red: 0.90, green: 0.42, blue: 0.08)
        case .trungThu: return Color(red: 0.11, green: 0.25, blue: 0.44)
        case .nhaGiao: return Color(red: 0.10, green: 0.40, blue: 0.72)
        case .noel: return Color(red: 0.73, green: 0.09, blue: 0.13)
        }
    }

    var primaryDark: Color {
        switch self {
        case .tetDuong: return Color(red: 0.15, green: 0.11, blue: 0.38)
        case .tet, .quocKhanh, .thongNhat: return Color(red: 0.50, green: 0.04, blue: 0.06)
        case .valentine: return Color(red: 0.55, green: 0.09, blue: 0.26)
        case .quocTePhuNu, .phuNuVietNam: return Color(red: 0.40, green: 0.12, blue: 0.40)
        case .gioTo, .thuongBinh: return Color(red: 0.38, green: 0.07, blue: 0.03)
        case .doanNgo: return Color(red: 0.06, green: 0.28, blue: 0.14)
        case .vuLan: return Color(red: 0.36, green: 0.08, blue: 0.18)
        case .thieuNhi: return Color(red: 0.66, green: 0.25, blue: 0.03)
        case .trungThu: return Color(red: 0.05, green: 0.12, blue: 0.26)
        case .nhaGiao: return Color(red: 0.05, green: 0.22, blue: 0.46)
        case .noel: return Color(red: 0.45, green: 0.04, blue: 0.07)
        }
    }

    /// Vài emoji rải mờ trong banner (seasonalBanner) và header (SeasonalHeaderScatter).
    var patternSymbols: [String] {
        switch self {
        case .tetDuong: return ["✨", "🎉", "🎆"]
        case .tet: return ["🌸", "🧧", "🏮"]
        case .valentine: return ["💕", "💘", "🌹"]
        case .quocTePhuNu, .phuNuVietNam: return ["🌷", "🌸", "💐"]
        case .gioTo: return ["🌾", "⭐"]
        case .doanNgo: return ["🍑", "🍉", "☀️"]
        case .thuongBinh: return ["⭐", "🕯️"]
        case .vuLan: return ["🌹", "🏮"]
        case .thieuNhi: return ["🎈", "⭐", "🍭"]
        case .quocKhanh, .thongNhat: return ["⭐", "🇻🇳"]
        case .trungThu: return ["🌕", "🏮", "⭐"]
        case .nhaGiao: return ["📚", "🌹", "✏️"]
        case .noel: return ["❄️", "🎄", "🎁"]
        }
    }

    /// Ma voucher đại diện — dùng cho nút xem trước bản dev (cần Ma để tìm icon AppIcon-<MA>).
    var maDaiDien: String {
        switch self {
        case .tetDuong: return "TETDUONG"
        case .tet: return "TETAL"
        case .valentine: return "VALENTINE"
        case .quocTePhuNu: return "QTPHUNU"
        case .phuNuVietNam: return "PHUNUVN"
        case .gioTo: return "GIOTO"
        case .doanNgo: return "DOANNGO"
        case .thuongBinh: return "THUONGBINH"
        case .vuLan: return "VULAN"
        case .thongNhat: return "GIAIPHONG"
        case .thieuNhi: return "THIEUNHI"
        case .quocKhanh: return "QUOCKHANH"
        case .trungThu: return "TRUNGTHU"
        case .nhaGiao: return "NHAGIAO"
        case .noel: return "NOEL"
        }
    }

    #if DEV_LOGIN
    /// Câu chúc MẪU chỉ dùng khi bấm "🧪 Xem trước" (chưa có voucher thật đang hiệu lực để lấy
    /// ten/moTa) — khớp đúng chữ đang lưu ở voucher tương ứng (Ma ở trên) tại thời điểm viết, sửa ở
    /// AppQuanLyIOS không tự đổi được bản xem trước này (chỉ ảnh hưởng câu chúc THẬT ngoài preview).
    var previewTen: String {
        switch self {
        case .tetDuong: return "Tết Dương lịch"
        case .tet: return "Tết Nguyên Đán"
        case .valentine: return "Valentine"
        case .quocTePhuNu: return "Quốc tế Phụ nữ 8/3"
        case .phuNuVietNam: return "Phụ nữ Việt Nam 20/10"
        case .gioTo: return "Giỗ Tổ Hùng Vương"
        case .doanNgo: return "Tết Đoan Ngọ"
        case .thuongBinh: return "Thương binh - Liệt sĩ 27/7"
        case .vuLan: return "Lễ Vu Lan & Rằm tháng Bảy"
        case .thongNhat: return "30/4 - 1/5"
        case .thieuNhi: return "Quốc tế Thiếu nhi"
        case .quocKhanh: return "Quốc khánh 2/9"
        case .trungThu: return "Tết Trung Thu"
        case .nhaGiao: return "Nhà giáo Việt Nam 20/11"
        case .noel: return "Giáng sinh"
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
    static var previewOverride: SeasonalTheme? {
        didSet { previewDipLe = nil }
    }
    /// Voucher thật của dịp đang xem trước (GET /dat-hang/dip-le?xemTruoc=MA) — để thấy câu chúc thật.
    private(set) static var previewDipLe: DipLe?

    @MainActor
    static func taiXemTruoc() async {
        guard let ma = previewOverride?.maDaiDien else { return }
        let env = await APIClient.shared.getDipLe(xemTruoc: ma)
        guard env.isSuccess, previewOverride?.maDaiDien == ma else { return }
        previewDipLe = env.data ?? nil
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
    }
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
        if let previewOverride {
            // Câu chúc THẬT của voucher dịp đó (taiXemTruoc); chưa tải xong/lỗi mạng thì câu mẫu.
            if let moTa = previewDipLe?.moTa, previewDipLe?.ma == previewOverride.maDaiDien { return moTa }
            return previewOverride.previewMoTa
        }
        #endif
        guard let dipLe else { return "" }
        let moTa = dipLe.moTa ?? ""
        // Voucher lễ yêu cầu hạng (hiện đều là Bạc) — trang trí thì ai cũng thấy, nhưng câu "Giảm 10%..."
        // chỉ hiện như lời hứa khi khách ĐỦ hạng; chưa đủ (kể cả khách chưa đăng nhập) thì ghi rõ điều
        // kiện, tránh khách tưởng ai cũng được giảm rồi đặt đơn mới biết không áp dụng.
        guard let hang = dipLe.hangToiThieu, !duHang(KhachHangSession.shared.hang, toiThieu: hang) else { return moTa }
        return moTa.isEmpty ? "🏅 Ưu đãi dành cho hạng \(hang) trở lên" : "🏅 Hạng \(hang) trở lên: \(moTa)"
    }

    private static let thuTuHang = ["Thành Viên", "Bạc", "Vàng", "Kim Cương"]

    /// Hạng lạ (không có trong danh sách) coi như chưa đủ — thà ghi điều kiện thừa còn hơn hứa sai.
    static func duHang(_ hang: String, toiThieu: String) -> Bool {
        guard let a = thuTuHang.firstIndex(of: hang), let b = thuTuHang.firstIndex(of: toiThieu) else { return false }
        return a >= b
    }

    /// Tải dịp lễ từ Backend — gọi lúc khởi động app (AppDatHangIOSApp) và mỗi lần mở lại tab Thực
    /// đơn (MenuView.task, khớp cách getBanChayIds tự refresh). applyNavBarAppearance lại vì nav bar
    /// là UIKit thuần, không tự vẽ lại theo SwiftUI diffing như Theme.primary ở các View khác.
    @MainActor
    static func load() async {
        let env = await APIClient.shared.getDipLe()
        // Lỗi mạng: giữ nguyên trạng thái cũ — nhất là KHÔNG đổi icon (hiểu nhầm "hết dịp" → 2 popup vô cớ).
        guard env.isSuccess else { return }
        let dipLe = env.data ?? nil
        self.dipLe = dipLe
        theme = dipLe.flatMap { SeasonalTheme(ma: $0.ma) }
        Theme.applyNavBarAppearance()
        // Lỗi mạng ở đây → giữ danh sách cũ (rỗng lúc mở app) = không trả icon về, an toàn hơn đổi nhầm.
        let daTat = await APIClient.shared.getDipLeDaTat()
        if daTat.isSuccess { maDaTat = Set(daTat.data ?? []) }
        capNhatIcon()
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
    }

    /// Ma các dịp có voucher đang tắt (GET /dat-hang/dip-le/da-tat) — icon dịp đó phải về icon quán.
    private(set) static var maDaTat: Set<String> = []

    @MainActor
    static func capNhatIcon() {
        var ma = dipLe?.ma
        #if DEV_LOGIN
        if let previewOverride { ma = previewOverride.maDaiDien }
        #endif
        AppIconSwitcher.capNhat(maDangDienRa: ma, maDaTat: maDaTat)
    }
}

/// Icon theo dịp lễ, kiểu Shopee: icon CHÍNH đổi bằng BẢN CẬP NHẬT (CI chọn icon dịp sắp tới lúc build,
/// scripts/chon-icon-dip-le.sh) → khách cập nhật đều đặn KHÔNG bao giờ thấy popup "You have changed the
/// icon…" (iOS bắt buộc hiện mỗi lần app tự đổi icon). Ở đây chỉ là lưới an toàn cho máy CHƯA cập nhật:
/// tới ngày lễ có icon mà icon chính bản đang cài không phải icon dịp đó → tự đổi, CÓ popup (user chấp
/// nhận 2026-11-05). Hết dịp không đổi gì — icon cứ giữ đến dịp có icon tiếp theo.
enum AppIconSwitcher {
    /// Ma có bộ AppIcon-<MA>.appiconset — phải khớp CFBundleAlternateIcons trong project.yml VÀ
    /// NhacDipLeService.MaCoIconApp (Backend, nhắc nộp cập nhật trước dịp).
    static let maCoIcon: Set<String> = [
        "NOEL", "TETAL", "VALENTINE", "TETDUONG", "QTPHUNU", "PHUNUVN", "GIOTO", "GIAIPHONG",
        "THIEUNHI", "DOANNGO", "THUONGBINH", "VULAN", "QUOCKHANH", "TRUNGTHU", "NHAGIAO",
    ]

    /// Icon phụ cần đặt: nil = icon chính của bản đang cài. Ngoài dịp có icon thì GIỮ NGUYÊN icon đang
    /// hiện (user 2026-11-05: "không cần quay lại icon chính, cứ để im đến đợt lễ tiếp theo") — chỉ đổi
    /// đúng lúc vào dịp có icon, nên máy chưa cập nhật gặp tối đa 1 popup/dịp.
    ///
    /// Ngoại lệ: voucher của dịp mà icon đang hiện bị TẮT (`maDaTat`, user 2026-11-05 "voucher dịp nào tắt
    /// thì tắt icon") → về icon quán: nil nếu icon chính bản cài là icon quán, "AppIcon-QUAN" nếu icon
    /// chính đã bị CI chép đè thành icon dịp.
    static func iconMucTieu(maDangDienRa: String?, maDongGoi: String, iconHienTai: String?,
                            maDaTat: Set<String> = []) -> String? {
        if let ma = maDangDienRa, maCoIcon.contains(ma) {
            return ma == maDongGoi ? nil : "AppIcon-\(ma)"
        }
        // Dịp của icon đang hiện: icon phụ "AppIcon-<MA>", hoặc không đặt icon phụ thì là icon chính bản cài.
        let maDangHien = iconHienTai.map { String($0.dropFirst("AppIcon-".count)) } ?? maDongGoi
        if !maDangHien.isEmpty, maDaTat.contains(maDangHien) {
            return maDongGoi.isEmpty ? nil : "AppIcon-QUAN"
        }
        return iconHienTai
    }

    @MainActor
    static func capNhat(maDangDienRa: String?, maDaTat: Set<String> = []) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let maDongGoi = Bundle.main.infoDictionary?["DennIconDip"] as? String ?? ""
        let iconHienTai = UIApplication.shared.alternateIconName
        let targetName = iconMucTieu(maDangDienRa: maDangDienRa, maDongGoi: maDongGoi, iconHienTai: iconHienTai,
                                     maDaTat: maDaTat)
        guard iconHienTai != targetName else { return }
        #if DEV_LOGIN
        // Bản dev: đổi icon KHÔNG hiện popup "You have changed the icon…" (bấm xem trước liên tục bị
        // popup — user 2026-11-05). Dùng selector NỘI BỘ của UIKit, nên CHỈ có ở DEV_LOGIN — bản App
        // Store không chứa code này (private API = bị từ chối duyệt), khách thật vẫn thấy popup như
        // mọi app iOS khác, không có cách công khai nào tắt.
        let sel = NSSelectorFromString(["_setAlternate", "IconName:", "completionHandler:"].joined())
        if UIApplication.shared.responds(to: sel) {
            typealias DoiIcon = @convention(c) (AnyObject, Selector, NSString?, @convention(block) (NSError?) -> Void) -> Void
            let doi = unsafeBitCast(UIApplication.shared.method(for: sel), to: DoiIcon.self)
            doi(UIApplication.shared, sel, targetName as NSString?) { _ in }
            return
        }
        #endif
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
        case .tet, .thieuNhi, .trungThu, .gioTo, .thuongBinh: return Color(red: 1.0, green: 0.97, blue: 0.91)
        case .doanNgo: return Color(red: 0.95, green: 0.985, blue: 0.95)
        case .valentine, .vuLan: return Color(red: 1.0, green: 0.945, blue: 0.955)
        case .quocTePhuNu, .phuNuVietNam: return Color(red: 0.985, green: 0.95, blue: 0.985)
        case .tetDuong: return Color(red: 0.965, green: 0.96, blue: 1.0)
        case .nhaGiao: return Color(red: 0.95, green: 0.97, blue: 1.0)
        case .noel, .quocKhanh, .thongNhat: return Color(red: 1.0, green: 0.962, blue: 0.94)
        }
    }

    var garlandWire: Color {
        switch self {
        case .noel: return Color(red: 0.13, green: 0.33, blue: 0.18)
        case .tet, .tetDuong, .trungThu, .gioTo, .thuongBinh: return Color(red: 0.93, green: 0.76, blue: 0.38)
        case .valentine, .quocTePhuNu, .phuNuVietNam, .nhaGiao, .thieuNhi, .doanNgo, .vuLan: return Color.white.opacity(0.75)
        case .quocKhanh, .thongNhat: return Color(red: 1.0, green: 0.86, blue: 0.3).opacity(0.8)
        }
    }

    enum GarlandItems {
        /// Bóng đèn vẽ tay có quầng sáng, xoay vòng các màu.
        case bulbs([Color])
        /// Cờ đuôi nheo tam giác, xoay vòng các màu.
        case flags([Color])
        case emoji([String])
    }

    var garlandItems: GarlandItems {
        switch self {
        case .noel:
            return .bulbs([Color(red: 1.0, green: 0.84, blue: 0.30), Color(red: 0.40, green: 0.85, blue: 0.45),
                           Color(red: 0.45, green: 0.78, blue: 1.0), Color(red: 1.0, green: 0.97, blue: 0.85)])
        case .tetDuong:
            return .bulbs([Color(red: 1.0, green: 0.84, blue: 0.30), Color(red: 1.0, green: 0.97, blue: 0.85)])
        case .gioTo, .thuongBinh:
            // Ngày tưởng niệm — chỉ cờ vàng/kem trang nghiêm, không đèn/tim/hình vui nhộn.
            return .flags([Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 1.0, green: 0.95, blue: 0.8)])
        case .quocKhanh, .thongNhat:
            return .flags([Color(red: 1.0, green: 0.85, blue: 0.2), .white])
        case .thieuNhi:
            return .flags([Color(red: 0.30, green: 0.65, blue: 1.0), Color(red: 1.0, green: 0.88, blue: 0.25),
                           Color(red: 0.40, green: 0.85, blue: 0.45), .white])
        case .tet: return .emoji(["🏮", "🌼"])
        case .valentine: return .emoji(["🤍", "💖"])
        case .quocTePhuNu, .phuNuVietNam: return .emoji(["🌷", "🌸"])
        case .trungThu: return .emoji(["🏮", "⭐"])
        case .nhaGiao: return .emoji(["🌹", "🌼"])
        case .doanNgo: return .emoji(["🍑", "🍉"])
        case .vuLan: return .emoji(["🌹", "🏮"])
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
        switch theme.garlandItems {
        case .bulbs(let colors):
            let color = colors[index % colors.count]
            // Quầng sáng mờ phía sau bóng đèn
            context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 1, width: 12, height: 14)),
                         with: .color(color.opacity(0.35)))
            context.fill(Path(CGRect(x: p.x - 1.5, y: p.y - 1, width: 3, height: 3)),
                         with: .color(Color(red: 0.12, green: 0.2, blue: 0.14)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y + 1.5, width: 6, height: 9)),
                         with: .color(color))
        case .flags(let colors):
            var flag = Path()
            flag.move(to: CGPoint(x: p.x - 5, y: p.y))
            flag.addLine(to: CGPoint(x: p.x + 5, y: p.y))
            flag.addLine(to: CGPoint(x: p.x, y: p.y + 10))
            flag.closeSubpath()
            context.fill(flag, with: .color(colors[index % colors.count]))
        case .emoji(let symbols):
            let resolved = context.resolve(Text(symbols[index % symbols.count]).font(.system(size: 11)))
            context.draw(resolved, at: CGPoint(x: p.x, y: p.y - 1), anchor: .top)
        }
    }
}
