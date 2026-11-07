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
        case .vuLan: return "🪷"
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
        case .vuLan: return "🕯️"
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
        case .quocTePhuNu: return Color(red: 0.66, green: 0.24, blue: 0.62)
        case .phuNuVietNam: return Color(red: 0.78, green: 0.27, blue: 0.33)
        case .gioTo, .thuongBinh: return Color(red: 0.62, green: 0.13, blue: 0.08)
        case .doanNgo: return Color(red: 0.13, green: 0.48, blue: 0.25)
        case .vuLan: return Color(red: 0.60, green: 0.16, blue: 0.30)
        case .thieuNhi: return Color(red: 0.12, green: 0.42, blue: 0.78)
        case .trungThu: return Color(red: 0.11, green: 0.25, blue: 0.44)
        case .nhaGiao: return Color(red: 0.09, green: 0.42, blue: 0.40)
        case .noel: return Color(red: 0.70, green: 0.07, blue: 0.11)
        }
    }

    var primaryDark: Color {
        switch self {
        case .tetDuong: return Color(red: 0.15, green: 0.11, blue: 0.38)
        case .tet, .quocKhanh, .thongNhat: return Color(red: 0.50, green: 0.04, blue: 0.06)
        case .valentine: return Color(red: 0.55, green: 0.09, blue: 0.26)
        case .quocTePhuNu: return Color(red: 0.40, green: 0.12, blue: 0.40)
        case .phuNuVietNam: return Color(red: 0.50, green: 0.12, blue: 0.17)
        case .gioTo, .thuongBinh: return Color(red: 0.38, green: 0.07, blue: 0.03)
        case .doanNgo: return Color(red: 0.06, green: 0.28, blue: 0.14)
        case .vuLan: return Color(red: 0.36, green: 0.08, blue: 0.18)
        case .thieuNhi: return Color(red: 0.05, green: 0.24, blue: 0.52)
        case .trungThu: return Color(red: 0.05, green: 0.12, blue: 0.26)
        case .nhaGiao: return Color(red: 0.04, green: 0.25, blue: 0.24)
        case .noel: return Color(red: 0.42, green: 0.03, blue: 0.06)
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
        case .vuLan: return ["🪷", "🕯️"]
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

    /// Màn chào ảnh riêng (ManChaoCache, tải từ server): tâm khối chữ chúc theo chiều cao màn hình — nằm giữa logo (mỗi ảnh logo một
    /// độ cao) và đồ trang trí dưới. Chỉnh theo ảnh thật, thêm dịp mới nhớ chỉnh dòng này.
    var manChaoChuY: CGFloat {
        switch self {
        case .noel: return 0.53
        case .tetDuong: return 0.50
        case .tet: return 0.68
        case .valentine: return 0.52
        case .quocTePhuNu: return 0.50
        case .gioTo: return 0.68
        case .thongNhat: return 0.56
        case .doanNgo: return 0.54
        case .thieuNhi: return 0.70
        case .thuongBinh: return 0.55
        case .vuLan: return 0.50
        case .quocKhanh: return 0.57
        case .trungThu: return 0.66
        case .phuNuVietNam: return 0.56
        case .nhaGiao: return 0.55
        }
    }

    /// Ảnh nền SÁNG (hồng) — chữ chúc dùng màu đậm của dịp thay vì trắng.
    var manChaoChuToi: Bool { self == .valentine }

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
        "🧪 Xem trước — Giảm 15%, tối đa 10.000đ nhân dịp \(previewTen)"
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
        // Voucher lễ yêu cầu hạng (hiện đều là Bạc) — trang trí thì ai cũng thấy, nhưng câu "Giảm 15%..."
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
        let env = await APIClient.shared.getDipLeHienThi()
        // Lỗi mạng: giữ nguyên trạng thái cũ — nhất là KHÔNG đổi icon (hiểu nhầm "hết dịp" → popup vô cớ).
        guard env.isSuccess, let kq = env.data else { return }
        dipLe = kq.giaoDien
        theme = kq.giaoDien.flatMap { SeasonalTheme(ma: $0.ma) }
        maIcon = kq.maIcon
        giuIcon = kq.giuIcon
        Theme.applyNavBarAppearance()
        capNhatIcon()
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
        // Ảnh màn chào tải ngầm khi dịp vào cửa sổ giao diện (xem ManChaoCache) — cold launch ngày đầu thì
        // ContentView chờ tải xong (tối đa vài giây) rồi mới hiện màn chào.
        // Dịp đang có icon (sớm hơn giao diện ~5 ngày): tải sẵn ngầm, không chờ.
        if let ma = kq.maIcon, let u = kq.anhManChaoIcon, ma != kq.giaoDien?.ma {
            Task { await ManChaoCache.taiNeuCan(ma: ma, duongDan: u) }
        }
        if let gd = kq.giaoDien, gd.anhManChao != nil { await ManChaoCache.taiNeuCan(ma: gd.ma, duongDan: gd.anhManChao) }
    }

    /// Dịp server bảo hiện icon (cửa sổ icon rộng hơn cửa sổ giao diện, có thể khác dịp với `theme`).
    private(set) static var maIcon: String?
    private(set) static var giuIcon = false

    /// Màn thoáng qua lúc mở app (kiểu banner sale Shopee) — chỉ hiện 1 lần/ngày cho mỗi dịp, tránh
    /// phiền khi khách mở app nhiều lần trong ngày. Key ghép Ma + ngày hôm nay (giờ máy khách, chỉ ảnh
    /// hưởng hiển thị, không phải mốc nghiệp vụ nên không cần VietnamTime).
    private static let khoaSplashDaXem = "seasonalSplash.daXemKey"

    private static func homNay() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func canHienSplash() -> Bool {
        // Chủ quán 2026-11-07: đẹp thì cho hiện MỖI LẦN mở app (cold launch) suốt cửa sổ giao diện (~4 ngày), không
        // giới hạn 1 lần/ngày nữa. Quay lại từ nền không hiện (ContentView chỉ gọi lúc khởi động).
        return active != nil
    }

    static func danhDauDaHienSplash() {
        guard let theme = active else { return }
        UserDefaults.standard.set("\(theme.maDaiDien)|\(homNay())", forKey: khoaSplashDaXem)
    }

    @MainActor
    static func capNhatIcon() {
        #if DEV_LOGIN
        // Bản dev đổi icon không popup (xem capNhat) → không cần giãn cách, bật/tắt xem trước thấy ngay.
        if let previewOverride {
            AppIconSwitcher.capNhat(maIcon: previewOverride.maDaiDien, boQuaGianCach: true)
            return
        }
        #endif
        guard !giuIcon else { return }
        #if DEV_LOGIN
        AppIconSwitcher.capNhat(maIcon: maIcon, boQuaGianCach: true)
        #else
        AppIconSwitcher.capNhat(maIcon: maIcon)
        #endif
    }
}

/// Icon theo dịp lễ: server quyết định lúc nào hiện icon dịp nào (GET /dat-hang/dip-le/hien-thi, DipLeLich ở
/// Backend: 7 ngày trước → 14 ngày sau lễ) — mọi icon đã đóng gói sẵn nên đổi KHÔNG cần ra bản cập nhật
/// (user 2026-11-06). iOS bắt buộc hiện popup "You have changed the icon…" mỗi lần đổi, không có cách công khai
/// nào tắt → giãn khoảng cách: server gộp khoảng trống ngắn giữa 2 dịp, app không đổi 2 lần trong
/// `soNgayToiThieu` ngày (đổi bị hoãn tới khi đủ ngày, không bỏ).
enum AppIconSwitcher {
    static let soNgayToiThieu = 7
    private static let khoaLanDoiCuoi = "appIconLanDoiCuoi"

    /// Ma có bộ AppIcon-<MA>.appiconset — phải khớp CFBundleAlternateIcons trong project.yml. Server bảo Ma
    /// không có ở đây (dịp thêm sau, bản app cũ) thì hiện icon quán.
    static let maCoIcon: Set<String> = [
        "NOEL", "TETAL", "VALENTINE", "TETDUONG", "QTPHUNU", "PHUNUVN", "GIOTO", "GIAIPHONG",
        "THIEUNHI", "DOANNGO", "THUONGBINH", "VULAN", "QUOCKHANH", "TRUNGTHU", "NHAGIAO",
    ]

    /// Tên icon phụ cần đặt (nil = icon quán), hoặc giữ nguyên `iconHienTai` nếu lần đổi trước chưa đủ
    /// `soNgayToiThieu` ngày.
    static func iconMucTieu(maIcon: String?, iconHienTai: String?, lanDoiCuoi: Date?, bayGio: Date = Date()) -> String? {
        let muonDoi = maIcon.flatMap { maCoIcon.contains($0) ? "AppIcon-\($0)" : nil }
        guard muonDoi != iconHienTai else { return iconHienTai }
        if let lanDoiCuoi, bayGio.timeIntervalSince(lanDoiCuoi) < Double(soNgayToiThieu) * 86_400 {
            return iconHienTai
        }
        return muonDoi
    }

    @MainActor
    static func capNhat(maIcon: String?, boQuaGianCach: Bool = false) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconHienTai = UIApplication.shared.alternateIconName
        let lanDoiCuoi = boQuaGianCach ? nil : UserDefaults.standard.object(forKey: khoaLanDoiCuoi) as? Date
        let targetName = iconMucTieu(maIcon: maIcon, iconHienTai: iconHienTai, lanDoiCuoi: lanDoiCuoi)
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
            if let error { print("[AppIconSwitcher] setAlternateIconName(\(targetName ?? "nil")) lỗi: \(error)"); return }
            DispatchQueue.main.async { UserDefaults.standard.set(Date(), forKey: khoaLanDoiCuoi) }
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
        case .tet, .trungThu, .gioTo, .thuongBinh: return Color(red: 1.0, green: 0.97, blue: 0.91)
        case .doanNgo: return Color(red: 0.95, green: 0.985, blue: 0.95)
        case .valentine, .vuLan, .phuNuVietNam: return Color(red: 1.0, green: 0.945, blue: 0.955)
        case .quocTePhuNu: return Color(red: 0.985, green: 0.95, blue: 0.985)
        case .tetDuong: return Color(red: 0.965, green: 0.96, blue: 1.0)
        case .thieuNhi: return Color(red: 0.95, green: 0.97, blue: 1.0)
        case .noel: return Color(red: 1.0, green: 0.962, blue: 0.94)
        case .nhaGiao: return Color(red: 0.94, green: 0.98, blue: 0.97)
        case .quocKhanh, .thongNhat: return Color(red: 1.0, green: 0.962, blue: 0.94)
        }
    }

    var garlandWire: Color {
        switch self {
        // Noel: dây xanh lá cây thông như icon (nền đỏ) — đủ sáng để không chìm vào header đỏ đậm.
        case .noel: return Color(red: 0.30, green: 0.62, blue: 0.36)
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
            // Quả châu vàng/trắng + đèn kem như icon Noel (bỏ bóng đỏ — chìm trên nền đỏ).
            return .bulbs([Color(red: 1.0, green: 0.84, blue: 0.30), .white,
                           Color(red: 0.40, green: 0.85, blue: 0.45), Color(red: 1.0, green: 0.97, blue: 0.85)])
        case .tetDuong:
            return .bulbs([Color(red: 1.0, green: 0.84, blue: 0.30), Color(red: 1.0, green: 0.97, blue: 0.85)])
        case .gioTo, .thuongBinh:
            // Ngày tưởng niệm — chỉ cờ vàng/kem trang nghiêm, không đèn/tim/hình vui nhộn.
            return .flags([Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 1.0, green: 0.95, blue: 0.8)])
        case .quocKhanh, .thongNhat:
            return .flags([Color(red: 1.0, green: 0.85, blue: 0.2), .white])
        case .thieuNhi:
            return .flags([Color(red: 0.95, green: 0.30, blue: 0.30), Color(red: 1.0, green: 0.88, blue: 0.25),
                           Color(red: 0.40, green: 0.85, blue: 0.45), .white])
        case .tet: return .emoji(["🏮", "🌼"])
        case .valentine: return .emoji(["🤍", "💖"])
        case .quocTePhuNu, .phuNuVietNam: return .emoji(["🌷", "🌸"])
        case .trungThu: return .emoji(["🏮", "⭐"])
        case .nhaGiao: return .emoji(["🌹", "🌼"])
        case .doanNgo: return .emoji(["🍑", "🍉"])
        case .vuLan: return .emoji(["🪷", "🕯️"])
        }
    }
}

/// Nền header dùng chung cho MỌI tab — gradient màu chủ đạo, dịp lễ thì thêm hoạ tiết mờ + dây trang
/// trí ở mép dưới. Header phải cộng thêm SeasonalGarland.extraBottom vào padding dưới để dây nằm GỌN
/// trong header, không đè lên nội dung bên dưới.
struct HeaderBackground: View {
    // Chụp màu/dịp lúc DỰNG view thành thuộc tính: view không có thuộc tính nào thì SwiftUI coi như không đổi và
    // bỏ qua body khi cha vẽ lại → header kẹt màu dịp cũ khi bấm xem trước (2026-11-07). Màu/dịp là static var.
    private let theme = SeasonalEvent.active
    private let mau = [Theme.primary, Theme.primaryDark]

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: mau, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea(edges: .top)
            if let theme {
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
