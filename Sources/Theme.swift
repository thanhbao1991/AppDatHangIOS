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
}

func formatTien(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.maximumFractionDigits = 0
    let number = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    return "\(number) đ"
}
