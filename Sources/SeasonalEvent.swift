import SwiftUI

/// Trang trí theo dịp lễ ở Home (banner + hạt rơi tuỳ dịp) — thay cho Theme.isChristmasSeason cũ (chỉ
/// Giáng sinh) để dùng chung cho mọi dịp. Ngày tính theo giờ VN (Asia/Ho_Chi_Minh), KHÔNG theo giờ hệ
/// thống máy khách, tự tắt khi qua ngày mà không cần phát hành bản mới (trừ Tết — bảng ngày âm lịch
/// cứng, PHẢI cập nhật tay mỗi năm, xem tetMung1).
enum SeasonalEvent: CaseIterable {
    case tet, valentine, christmas, quocKhanh, thongNhat

    var bannerTitle: String {
        switch self {
        case .tet: return "Chúc Mừng Năm Mới!"
        case .valentine: return "Happy Valentine!"
        case .christmas: return "Chúc Mừng Giáng Sinh!"
        case .quocKhanh: return "Mừng Quốc Khánh 2/9"
        case .thongNhat: return "30/4 - 1/5"
        }
    }

    var bannerSubtitle: String {
        switch self {
        case .tet: return "Đenn Coffee chúc bạn năm mới an khang, vạn sự như ý 🧧"
        case .valentine: return "Đenn Coffee chúc bạn một ngày lễ tình nhân ngọt ngào 💕"
        case .christmas: return "Đenn Coffee chúc bạn một mùa lễ ấm áp 🎁"
        case .quocKhanh: return "Đenn Coffee chúc mừng ngày Quốc khánh nước nhà 🇻🇳"
        case .thongNhat: return "Đenn Coffee chúc bạn kỳ nghỉ lễ vui vẻ 🇻🇳"
        }
    }

    var leadingEmoji: String {
        switch self {
        case .tet: return "🧧"
        case .valentine: return "💘"
        case .christmas: return "🎄"
        case .quocKhanh: return "🇻🇳"
        case .thongNhat: return "🇻🇳"
        }
    }

    var trailingEmoji: String {
        switch self {
        case .tet: return "🌸"
        case .valentine: return "💖"
        case .christmas: return "❄️"
        case .quocKhanh: return "⭐"
        case .thongNhat: return "⭐"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .tet: return [Color(red: 0.80, green: 0.08, blue: 0.1), Color(red: 0.93, green: 0.65, blue: 0.1)]
        case .valentine: return [Color(red: 0.87, green: 0.18, blue: 0.42), Color(red: 0.98, green: 0.55, blue: 0.65)]
        case .christmas: return [Color(red: 0.73, green: 0.09, blue: 0.13), Color(red: 0.12, green: 0.47, blue: 0.24)]
        case .quocKhanh, .thongNhat: return [Color(red: 0.80, green: 0.08, blue: 0.1), Color(red: 0.80, green: 0.08, blue: 0.1).opacity(0.85)]
        }
    }

    /// nil = không có hạt rơi (2/9 và 30/4-1/5 trang nghiêm hơn, chỉ banner) — xem feedback 2026-11-05.
    var particleSymbol: String? {
        switch self {
        case .tet: return "🌸"
        case .valentine: return "❤️"
        case .christmas: return nil // Giáng sinh dùng SnowfallView riêng (hình tròn viền xanh, không phải emoji)
        case .quocKhanh, .thongNhat: return nil
        }
    }

    /// Mùng 1 Tết dương lịch — PHẢI thêm năm mới vào bảng này mỗi dịp cuối năm, không tính được bằng
    /// công thức (âm lịch). Thiếu năm nào thì Tết năm đó không trang trí (an toàn, không crash).
    private static let tetMung1: [Int: (month: Int, day: Int)] = [
        2026: (2, 17),
        2027: (2, 6),
    ]

    #if DEV_LOGIN
    /// Công tắc xem thử bất kể ngày thật — CHỈ có ở bản dev (DEV_LOGIN), bật ở SettingsView khu "🧪 Xem
    /// trước...". nil = không ghi đè (dùng ngày thật).
    static var previewOverride: SeasonalEvent?
    #endif

    /// Dịp đang hiệu lực theo giờ VN — nil nếu không trúng dịp nào. Trùng ngày (lý thuyết không xảy ra
    /// với các mốc đã chọn) thì ưu tiên theo thứ tự khai báo ở CaseIterable.
    static func active(now: Date = Date()) -> SeasonalEvent? {
        #if DEV_LOGIN
        if let previewOverride { return previewOverride }
        #endif
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: now)
        guard let year = c.year, let month = c.month, let day = c.day else { return nil }

        if let mung1 = tetMung1[year] {
            let mung1Date = cal.date(from: DateComponents(year: year, month: mung1.month, day: mung1.day)) ?? now
            let today = cal.startOfDay(for: now)
            let diff = cal.dateComponents([.day], from: mung1Date, to: today).day ?? 999
            // 29-30 Tết (2 ngày trước) + mồng 1 = 3 ngày
            if diff >= -2 && diff <= 0 { return .tet }
        }
        if month == 2 && day == 14 { return .valentine }
        if month == 12 && (day == 24 || day == 25) { return .christmas }
        if month == 9 && day == 2 { return .quocKhanh }
        if (month == 4 && day == 30) || (month == 5 && day == 1) { return .thongNhat }
        return nil
    }
}
