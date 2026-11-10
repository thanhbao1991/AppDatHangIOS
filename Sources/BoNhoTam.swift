import Foundation

/// Bộ nhớ tạm (chỉ trong RAM, mất khi tắt app) cho tab Tài khoản / Ưu đãi — 09/11/2026, chủ quán: mở tab phải nhìn
/// vòng xoay chờ /vi. Mở lại tab thì hiện ngay dữ liệu lần trước, rồi tải lại lặng lẽ thay vào.
/// Xoá cùng Prefs.clear() (đăng xuất/hết phiên) để không lộ dữ liệu khách trước sang tài khoản sau.
///
/// 10/11/2026 (ảnh chủ quán đổi tài khoản Hân ↔ Hoà): đăng xuất xoá bộ nhớ RỒI SettingsView.onDisappear mới chạy
/// luuBoNhoTam() → ghi lại dữ liệu khách cũ → tài khoản sau mở tab thấy ví/địa chỉ/công nợ của khách trước, rương Xu
/// chạy "+N" sai. Giờ mọi dữ liệu gắn với khách sở hữu (Prefs.khachHangId lúc ghi); đọc khi khách đã đổi → coi như trống.
enum BoNhoTam {
    private static var chuSoHuu: String?

    /// Gọi ở đầu mọi lần đọc/ghi: khách đổi → xoá sạch, nhận chủ mới.
    private static func dungChu() {
        let hienTai = Prefs.khachHangId
        if chuSoHuu != hienTai {
            xoaDuLieu()
            chuSoHuu = hienTai
        }
    }

    private static var _vi: KhachHangVi?
    private static var _diaChiList: [DiaChiKhachHang]?
    private static var _ngaySinhInfo: SinhNhatInfo?
    private static var _soLuotConLai: Int?
    private static var _diemDanh: DiemDanhInfo?
    private static var _donCuaToi: [DonHangKhach]?
    private static var _thongBao: [ThongBao]?
    private static var _bangXepHang: BangXepHang?

    static var vi: KhachHangVi? {
        get { dungChu(); return _vi }
        set { dungChu(); _vi = newValue }
    }
    static var diaChiList: [DiaChiKhachHang]? {
        get { dungChu(); return _diaChiList }
        set { dungChu(); _diaChiList = newValue }
    }
    static var ngaySinhInfo: SinhNhatInfo? {
        get { dungChu(); return _ngaySinhInfo }
        set { dungChu(); _ngaySinhInfo = newValue }
    }
    static var soLuotConLai: Int? {
        get { dungChu(); return _soLuotConLai }
        set { dungChu(); _soLuotConLai = newValue }
    }
    static var diemDanh: DiemDanhInfo? {
        get { dungChu(); return _diemDanh }
        set { dungChu(); _diemDanh = newValue }
    }
    static var donCuaToi: [DonHangKhach]? {
        get { dungChu(); return _donCuaToi }
        set { dungChu(); _donCuaToi = newValue }
    }
    static var thongBao: [ThongBao]? {
        get { dungChu(); return _thongBao }
        set { dungChu(); _thongBao = newValue }
    }
    static var bangXepHang: BangXepHang? {
        get { dungChu(); return _bangXepHang }
        set { dungChu(); _bangXepHang = newValue }
    }

    static func xoa() {
        xoaDuLieu()
        // Ghi muộn sau đăng xuất (onDisappear) vẫn mang khachHangId cũ → lần đọc của khách mới sẽ tự bỏ.
        chuSoHuu = Prefs.khachHangId
    }

    private static func xoaDuLieu() {
        _vi = nil
        _diaChiList = nil
        _ngaySinhInfo = nil
        _soLuotConLai = nil
        _diemDanh = nil
        _donCuaToi = nil
        _thongBao = nil
        _bangXepHang = nil
    }
}
