import Foundation

/// Câu chữ giải thích lấy từ backend (GET /dat-hang/noi-dung, NoiDungApp.cs) — sửa chữ ở backend là app đổi theo,
/// KHÔNG phải nộp lại App Store (2026-10-26). Lưu bản mới nhất vào UserDefaults; chưa tải được thì dùng câu mặc
/// định build sẵn bên dưới (giữ khớp NoiDungApp.cs lúc build).
enum NoiDung {
    private static let key = "noiDungApp"

    private static let macDinh: [String: String] = [
        "napXuGhiChu": "Xu dùng để thanh toán đơn đặt trên app (không dùng tại quầy), 1 Xu = 1đ. Xu đã nạp không quy đổi lại thành tiền mặt.",
        "xoaTaiKhoanMoTa": "Nếu tài khoản còn công nợ, bạn cần thanh toán hết trước khi xoá. Số dư Xu (nếu có) vẫn được quán giữ nguyên, dùng lại được khi bạn đăng ký lại app bằng cùng số điện thoại.\n\nXoá tài khoản sẽ xoá mật khẩu hiện tại và ngày sinh đã khai, thu hồi mọi phiên đăng nhập. Bạn sẽ không còn thấy lại đơn hàng, thẻ tích điểm, lịch sử Xu hay địa chỉ đã lưu trong app, kể cả nếu đăng ký lại sau này. Số điện thoại, tên và lịch sử mua hàng vẫn được quán lưu giữ (kế toán, chăm sóc khách hàng ngoài app) — xem Chính sách bảo mật. Không thể hoàn tác.",
        "hangGhiChu": "Chỉ tính đơn đặt qua app. Nước lon, ăn vặt và món không pha chế không được tính vào hạng.\n\nChương trình do Đenn Coffee tổ chức, miễn phí cho khách hàng. Apple không tài trợ và không liên quan đến chương trình này.",
        "hopQuaTaiTro": "Chương trình do Đenn Coffee tổ chức, miễn phí cho khách hàng. Apple không tài trợ và không liên quan đến chương trình này.",
        "chucMungHangTieuDe": "Bạn đạt hạng {hang}\n{thang}",
        "chucMungHangPhu": "Cảm ơn bạn đã đồng hành cùng Đenn!",
        "chucMungTopTieuDe": "Top {viTri} người dùng\n{thang}",
        "chucMungTopPhu": "Cảm ơn bạn đã đồng hành cùng Đenn!",
        "chucMungChuyenDiemTieuDe": "Điểm tích ở quầy\nđã thành Xu",
        "chucMungChuyenDiemPhu": "Đã cộng vào ví. Từ nay mỗi 300.000đ đặt qua app nhận 10.000 Xu.",
        "shipMienPhiGhiChu": "Đơn từ 2 ly, hoặc chi tiêu từ 300k/tháng freeship",
        "muaHoGiam": "Giảm 5% hoặc Voucher, ưu tiên giảm nhiều hơn!",
        "muaHoGiuVoucher": "Giảm 5% nhiều hơn voucher đã chọn — voucher được giữ lại cho lần sau.",
        "tangLuotQuaKhiHoanThanh": "🎁 Tặng 1 lượt quà Xu khi hoàn thành đơn",
        "napLanDauTieuDe": "Nạp lần đầu: nhân đôi Xu tặng",
        "napLanDauMoTa": "Số Xu tặng bên dưới đã gồm phần nhân đôi.",
        "voucherKhongApDung": "Nước lon, ăn vặt và món không pha chế không áp dụng voucher.",
        "donTinhHangGiaiThich": "Chỉ đơn bạn tự đặt qua app mới được tính vào hạng thành viên. Nước lon, ăn vặt và món không pha chế không được tính.",
        "sinhNhatDaNhan": "Bạn đã nhận voucher mừng sinh nhật trong năm nay, phải đợi qua năm mới được sửa.",
        "otpGhiChu": "Mã xác thực sẽ được gửi qua Zalo, vui lòng nhập số điện thoại đang dùng Zalo.",
        "otpNhapMa": "Nhập mã OTP đã gửi qua Zalo",
        "qrNhacNoiDung": "Quý khách vui lòng không thay đổi nội dung chuyển khoản (ghi chú)!",
        "napXuGiuNoiDung": "Giữ nguyên số tiền và nội dung \"{noiDung}\" để Xu được cộng tự động.",
    ]

    private static var daLuu: [String: String] =
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]

    static func text(_ k: String) -> String {
        if let s = daLuu[k], !s.isEmpty { return s }
        return macDinh[k] ?? ""
    }

    /// Gọi lúc mở app — lỗi mạng thì giữ bản đã lưu.
    static func taiLai() async {
        guard let moi = await APIClient.shared.getNoiDung(), !moi.isEmpty else { return }
        await MainActor.run {
            daLuu = moi
            UserDefaults.standard.set(moi, forKey: key)
        }
    }

    static var napXuGhiChu: String { text("napXuGhiChu") }
    static var xoaTaiKhoanMoTa: String { text("xoaTaiKhoanMoTa") }
    static var hangGhiChu: String { text("hangGhiChu") }
    static var hopQuaTaiTro: String { text("hopQuaTaiTro") }
}
