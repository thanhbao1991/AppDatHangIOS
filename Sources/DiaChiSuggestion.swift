import Foundation

/// Gợi ý tên đường khi khách gõ địa chỉ — dùng chung cho mọi nơi nhập địa chỉ trong app (trước chỉ
/// có ở CheckoutView, tách ra đây 2026-09-27 để SettingsView (Thêm/Sửa địa chỉ ở tab Tài khoản) dùng
/// lại được, tránh viết trùng 2 lần cùng 1 logic regex số nhà.
enum DiaChiSuggestion {
    /// Khớp TenDuongBox bên Desktop: số nhà + ký tự phụ (vd "12A", "12/3B") + dấu ngăn cách phía sau
    /// — phần CÒN LẠI sau prefix này mới là fragment để so khớp/thay thế tên đường.
    private static let houseNumberPrefixRegex = try! NSRegularExpression(pattern: "^\\d+[A-Za-z]{0,2}(/\\d+[A-Za-z]{0,2})?[\\s.,-]*")

    private static func houseNumberPrefixRange(in text: String) -> Range<String.Index>? {
        let range = NSRange(text.startIndex..., in: text)
        guard let m = houseNumberPrefixRegex.firstMatch(in: text, range: range) else { return nil }
        return Range(m.range, in: text)
    }

    static func streetFragment(_ text: String) -> String {
        guard let r = houseNumberPrefixRange(in: text) else { return text }
        return String(text[r.upperBound...])
    }

    static func housePrefix(_ text: String) -> String {
        guard let r = houseNumberPrefixRange(in: text) else { return "" }
        return String(text[..<r.upperBound])
    }

    /// Danh sách tên đường khớp phần fragment (sau số nhà) khách đang gõ — rỗng nếu đang gõ trùng
    /// khớp DUY NHẤT 1 tên đường sẵn có (coi như đã chọn xong, khỏi hiện gợi ý thừa).
    static func matches(for text: String, in tenDuongs: [TenDuong], limit: Int = 8) -> [String] {
        let fragment = streetFragment(text).trimmingCharacters(in: .whitespaces)
        guard !fragment.isEmpty else { return [] }
        let norm = normalizeVN(fragment)
        let ketQua = tenDuongs.map(\.ten).filter { normalizeVN($0).contains(norm) }
        if ketQua.count == 1 && normalizeVN(ketQua[0]) == norm { return [] }
        return Array(ketQua.prefix(limit))
    }

    /// Ghép số nhà đã gõ + tên đường được chọn từ gợi ý, thay hẳn phần tên đường cũ (nếu có).
    static func apply(_ ten: String, to text: String) -> String {
        housePrefix(text) + ten
    }
}
