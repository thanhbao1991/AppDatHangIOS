import Foundation

/// Bộ nhớ tạm (chỉ trong RAM, mất khi tắt app) cho tab Tài khoản / Ưu đãi — 09/11/2026, chủ quán: mở tab phải nhìn
/// vòng xoay chờ /vi. Mở lại tab thì hiện ngay dữ liệu lần trước, rồi tải lại lặng lẽ thay vào.
/// Xoá cùng Prefs.clear() (đăng xuất/hết phiên) để không lộ dữ liệu khách trước sang tài khoản sau.
enum BoNhoTam {
    static var vi: KhachHangVi?
    static var diaChiList: [DiaChiKhachHang]?
    static var ngaySinhInfo: SinhNhatInfo?
    static var soLuotConLai: Int?
    static var diemDanh: DiemDanhInfo?
    static var donCuaToi: [DonHangKhach]?
    static var thongBao: [ThongBao]?
    static var bangXepHang: BangXepHang?

    static func xoa() {
        vi = nil
        diaChiList = nil
        ngaySinhInfo = nil
        soLuotConLai = nil
        diemDanh = nil
        donCuaToi = nil
        thongBao = nil
        bangXepHang = nil
    }
}
