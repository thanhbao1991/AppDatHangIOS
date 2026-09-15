import Foundation
import SwiftUI

// Port 1:1 từ src/api.ts (bản RN cũ, xem lịch sử git trước commit chuyển native) — field name phải
// khớp tuyệt đối JSON backend trả về (không có CodingKeys riêng, tên property Swift = tên field JSON).

/// Giờ mở/đóng cửa quán — xem GamificationConfig.GioMoCua/GioDongCua bên Backend.
struct GioMoBanDto: Decodable {
    let gioMoCua: Int
    let gioDongCua: Int

    /// So theo giờ VN thật (Asia/Ho_Chi_Minh), không phải giờ hệ thống máy khách — phòng trường hợp
    /// máy đặt sai múi giờ. Server vẫn là nơi chặn thật (DatMonAsync); đây chỉ để hiện banner/khoá
    /// nút sớm cho UX, không phải chốt chặn duy nhất.
    var dangMoCua: Bool {
        let cal = Calendar(identifier: .gregorian)
        var vn = cal
        vn.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        let gio = vn.component(.hour, from: Date())
        return gio >= gioMoCua && gio < gioDongCua
    }
}

struct ApiEnvelope<T: Decodable>: Decodable {
    let isSuccess: Bool
    let message: String?
    let data: T?
    let warnings: [String]?
}

struct ActionResult { let success: Bool; let message: String? }

// ---- Auth ----

struct LoginRequest: Encodable { let soDienThoai: String; let matKhau: String; let thietBi: String?; let nenTang: String?; let thietBiId: String? }
struct OtpConfirmRequest: Encodable { let soDienThoai: String; let otp: String; let matKhau: String; let thietBi: String?; let nenTang: String?; let thietBiId: String? }
struct RefreshRequest: Encodable { let refreshToken: String; let thietBi: String?; let nenTang: String?; let thietBiId: String? }

struct KhachHangLoginResponse: Decodable {
    let thanhCong: Bool?
    let message: String?
    let token: String?
    let refreshToken: String?
    let khachHangId: String?
    let tenKhachHang: String?
    let avatarUrl: String?
}

enum LoginResult {
    case success(KhachHangLoginResponse)
    case rejected(String)
    case networkError
}

struct PhienDangNhapKhachHang: Decodable, Identifiable {
    let id: String
    let thietBi: String?
    let nenTang: String?
    let ngayTao: String
    let hetHan: String
    let laThietBiHienTai: Bool
}

// ---- Catalog ----

struct SanPhamBienThe: Decodable, Identifiable, Hashable {
    let id: String
    let tenBienThe: String
    let giaBan: Double
    let macDinh: Bool
}

struct SanPham: Decodable, Identifiable {
    let id: String
    let ten: String
    let ngungBan: Bool
    let nhomSanPhamId: String?
    let hinhAnh: String?
    let bienThe: [SanPhamBienThe]
    let timKiem: String?
    let storeFoodId: Int?
    let khongLenStore: Bool
}

struct NhomSanPham: Decodable, Identifiable { let id: String; let ten: String }
/// Danh sách tên đường dùng gợi ý khi khách gõ địa chỉ giao hàng — cùng nguồn TenDuong Desktop dùng
/// cho TenDuongBox (nhân viên tạo đơn), xem CheckoutView.diaChiSuggestions.
struct TenDuong: Decodable, Identifiable { let id: String; let ten: String }

/// Parse "nguong1:giam1,nguong2:giam2,..." (Voucher.BacThang bên Backend) — dùng chung cho Voucher
/// và VoucherCuaToi, tránh viết lặp 2 lần. nil nếu chuỗi rỗng/không hợp lệ.
private func parseBacThang(_ raw: String?) -> [(nguong: Double, giam: Double)]? {
    guard let raw, !raw.isEmpty else { return nil }
    let bacs = raw.split(separator: ",").compactMap { phan -> (nguong: Double, giam: Double)? in
        let parts = phan.split(separator: ":")
        guard parts.count == 2, let n = Double(parts[0]), let g = Double(parts[1]) else { return nil }
        return (n, g)
    }
    return bacs.isEmpty ? nil : bacs
}

/// Bậc CAO NHẤT mà donGiaTri đạt được trong danh sách bacs — khớp
/// DatHangService.VoucherBacThangHelper.BacApDung (không cộng dồn nhiều bậc).
private func bacApDung(_ bacs: [(nguong: Double, giam: Double)], donGiaTri: Double) -> Double? {
    bacs.filter { donGiaTri >= $0.nguong }.map(\.giam).max()
}

/// Voucher khả dụng cho khách hiện tại — chỉ những cái ĐANG đủ điều kiện (xem
/// DatHangService.GetVoucherKhaDungAsync), không có dieuKien/dangHoatDong vì đó là chi tiết nội bộ.
struct Voucher: Decodable, Identifiable, Equatable {
    let id: String
    let ma: String
    let ten: String
    let moTa: String?
    let soTienGiam: Double
    // "SoTien" (mặc định) | "PhanTram" — xem VoucherLoaiGiam bên Backend.
    var loaiGiam: String = "SoTien"
    var phanTramGiam: Double?
    // Trần giảm tối đa — chỉ có ý nghĩa khi loaiGiam == "PhanTram". Xem VoucherEntity.GiamToiDa.
    var giamToiDa: Double?
    var donToiThieu: Double?
    // Chỉ có ý nghĩa khi voucher là bậc thang (DieuKien=DonToiThieuBac nội bộ) — có giá trị thì LOẠI
    // GIẢM/PHẦN TRĂM ở trên vô nghĩa, ưu tiên dùng field này. Xem VoucherEntity.BacThang.
    var bacThang: String?
    // true khi voucher CHỈ dùng được khi giỏ có ít nhất 1 dòng Size L (DieuKien=UpsizeMonMoi nội bộ) —
    // KHÔNG ảnh hưởng số tiền giảm (vẫn cố định soTienGiam như voucher thường), chỉ để CheckoutView tự
    // ẩn voucher này khi giỏ hàng không có Size L. Xem VoucherKhaDungDto.ChiApDungKhiCoSizeL.
    var chiApDungKhiCoSizeL: Bool = false

    /// Số tiền giảm thực tế cho đơn hiện tại — bậc thang thì tra bảng bacThang, còn lại PhanTram tính
    /// trên tổng tiền hàng (làm tròn LÊN hàng nghìn đồng rồi chặn trần giamToiDa), SoTien (kể cả
    /// UpsizeMonMoi) thì cố định soTienGiam — khớp DatHangService.TinhSoTienGiam bên Backend.
    func soTienGiamThucTe(tongTienHang: Double, cartItems: [CartItem] = []) -> Double {
        if let bacs = parseBacThang(bacThang) {
            return min(bacApDung(bacs, donGiaTri: tongTienHang) ?? 0, tongTienHang)
        }
        guard loaiGiam == "PhanTram" else { return soTienGiam }
        let giam = ceil(tongTienHang * (phanTramGiam ?? 0) / 100 / 1000) * 1000
        if let giamToiDa, giamToiDa > 0 { return min(giam, giamToiDa) }
        return giam
    }

    /// Nhãn giảm giá dạng RATE (không phải tiền quy đổi cho 1 đơn cụ thể) — khớp
    /// VoucherCuaToi.nhanGiamGia, dùng làm headline ở sheet "Chọn voucher" (CheckoutView) để cùng 1
    /// voucher không hiện 2 con số khác nhau giữa tab Voucher và lúc đặt hàng. Bậc thang không có 1
    /// "rate" duy nhất — hiện mức giảm CAO NHẤT có thể đạt ("Lên đến Xđ").
    var nhanGiamGia: String {
        if let bacs = parseBacThang(bacThang), let max = bacs.map(\.giam).max() {
            return "Lên đến -\(formatTien(max))"
        }
        return loaiGiam == "PhanTram" ? "-\(Int(phanTramGiam ?? 0))%" : "-\(formatTien(soTienGiam))"
    }

    /// "Tối đa Xđ" khi voucher % có trần giảm — khớp VoucherCuaToi.nhanGiamToiDa, hiện Y HỆT tab
    /// Voucher (không hiện số tiền quy đổi riêng cho đơn hiện tại). nil cho bậc thang — "Đơn từ Xđ"
    /// (mốc thấp nhất) đã có sẵn qua field donToiThieu, đủ ngữ cảnh không cần dòng phụ này nữa.
    var nhanGiamToiDa: String? {
        guard bacThang == nil, loaiGiam == "PhanTram", let giamToiDa, giamToiDa > 0 else { return nil }
        return "Tối đa \(formatTien(giamToiDa))"
    }
}

/// Voucher của tài khoản cho tab Ưu đãi — CẢ đã dùng lẫn chưa, khác Voucher (chỉ còn dùng được) ở
/// CheckoutView. Xem DatHangService.GetVoucherCuaToiAsync.
struct VoucherCuaToi: Decodable, Identifiable {
    let id: String
    let ma: String
    let ten: String
    let moTa: String?
    let soTienGiam: Double
    var loaiGiam: String = "SoTien"
    var phanTramGiam: Double?
    var giamToiDa: Double?
    var donToiThieu: Double?
    var bacThang: String?
    let daSuDung: Bool

    /// Nhãn giảm giá cho tab Ưu đãi — không có đơn cụ thể để tính số tiền thật cho voucher %,
    /// nên hiện "-X%" thay vì "-0đ" (khớp cách AppQuanLyIOS hiện cho staff). Bậc thang hiện mức giảm
    /// CAO NHẤT có thể đạt, khớp Voucher.nhanGiamGia bên CheckoutView.
    var nhanGiamGia: String {
        if let bacs = parseBacThang(bacThang), let max = bacs.map(\.giam).max() {
            return "Lên đến -\(formatTien(max))"
        }
        return loaiGiam == "PhanTram" ? "-\(Int(phanTramGiam ?? 0))%" : "-\(formatTien(soTienGiam))"
    }

    /// "Tối đa Xđ" khi voucher % có trần giảm — nil khi không áp dụng (SoTien/bậc thang hoặc không
    /// giới hạn).
    var nhanGiamToiDa: String? {
        guard bacThang == nil, loaiGiam == "PhanTram", let giamToiDa, giamToiDa > 0 else { return nil }
        return "Tối đa \(formatTien(giamToiDa))"
    }
}
struct Topping: Decodable, Identifiable { let id: String; let ten: String; let gia: Double; let ngungBan: Bool }

// ---- Đặt món ----

struct DatMonToppingItem: Encodable { let toppingId: String; let soLuong: Int }
struct DatMonItem: Encodable { let sanPhamBienTheId: String; let soLuong: Int; let ghiChu: String?; let toppings: [DatMonToppingItem] }
struct DatMonRequest: Encodable {
    let items: [DatMonItem]
    let ghiChu: String?
    let diaChiText: String
    let soDienThoaiText: String?
    let deliveryLat: Double?
    let deliveryLong: Double?
    let clientOrderId: String?
    let nhanTaiQuan: Bool
    let dungVi: Bool
    let hinhThucThanhToan: String?
    let voucherId: String?
}
struct DatMonResponse: Decodable { let id: String; let thanhTien: Double }

struct UocTinhShipRequest: Encodable { let lat: Double; let long: Double; let tongTienDon: Double }
struct TuyenDuongPoint: Decodable { let lat: Double; let long: Double }
struct UocTinhShip: Decodable {
    // Backend LUÔN trả giá trị từ 2026-09-14 (không còn mốc "đơn đủ lớn thì miễn phí bất kể xa gần"
    // bỏ qua OSRM) — vẫn để optional cho an toàn kiểu dữ liệu, xem DatHangService.UocTinhPhiShip.
    let khoangCachKm: Double?
    let phiShip: Double
    let shopLat: Double
    let shopLong: Double
    let tuyenDuong: [TuyenDuongPoint]?
}

struct DonHangKhachItemTopping: Decodable, Identifiable, Hashable {
    let toppingId: String
    let ten: String
    let gia: Double
    let soLuong: Int
    var id: String { toppingId }
}

struct DonHangKhachItem: Decodable, Identifiable, Hashable {
    let sanPhamBienTheId: String
    let tenSanPham: String
    let tenBienThe: String
    let soLuong: Int
    let donGia: Double
    let ghiChu: String?
    let toppings: [DonHangKhachItemTopping]
    let hinhAnh: String?
    var id: String { sanPhamBienTheId }
}

enum TrangThaiDon: String, Decodable, Hashable, CaseIterable {
    case choXacNhan = "ChoXacNhan", daXacNhan = "DaXacNhan", dangGiao = "DangGiao", hoanTat = "HoanTat"

    var nhan: String {
        switch self {
        case .choXacNhan: return "Chờ quán xác nhận"
        case .daXacNhan: return "Quán đã nhận, đang chuẩn bị"
        case .dangGiao: return "Đang giao"
        case .hoanTat: return "Hoàn tất"
        }
    }

    var mau: Color {
        switch self {
        case .choXacNhan: return Theme.warning
        case .daXacNhan: return Theme.primary
        case .dangGiao: return Color(red: 0x19 / 255, green: 0x76 / 255, blue: 0xD2 / 255)
        case .hoanTat: return Theme.success
        }
    }
}

struct DonHangKhach: Decodable, Identifiable, Hashable {
    let id: String
    let maHoaDon: String
    let ngayGio: String
    let tongTien: Double
    let giamGia: Double
    let thanhTien: Double
    let daThu: Double
    let conLai: Double
    let tenMonSummary: String
    let phanLoai: String?
    let tenBan: String?
    let diaChiText: String?
    let soDienThoaiText: String?
    let ghiChu: String?
    let items: [DonHangKhachItem]
    let trangThai: TrangThaiDon
    let daDanhGia: Bool
    let soSaoDaDanh: Int?
    /// Đơn "Nhận tại quán" đã hoàn tất được mở quà Xu chưa — điều kiện HIỆN nút "Mở quà": trangThai
    /// == .hoanTat && diaChiText == "Nhận tại quán" && !daMoQuaXu (server validate lại đầy đủ).
    let daMoQuaXu: Bool
}

// ---- Địa chỉ ----

struct DiaChiKhachHang: Decodable, Identifiable {
    let id: String
    let diaChi: String
    let isDefault: Bool
    let lat: Double?
    let long: Double?
    // false = địa chỉ do quán nhập từ Desktop — khách chỉ được dùng, không xoá được (backend cũng
    // chặn nếu app lỡ gọi xoaDiaChi, nhưng ẩn nút ở đây cho khỏi bấm hụt).
    let coTheXoa: Bool
}

// ---- Thông báo ----

enum LoaiThongBao: String, Decodable { case donHang = "DonHang", khuyenMai = "KhuyenMai" }
struct ThongBao: Decodable, Identifiable {
    let id: String
    let loai: LoaiThongBao
    let tieude: String
    let noiDung: String
    let ngayTao: String
    let hoaDonId: String?
}

// ---- Ví / gamification ----

struct FavoriteItem: Decodable, Hashable { let tenSanPham: String; let tenBienThe: String }
struct KhachHangVi: Decodable {
    let soDu: Double
    let diemThangNay: Double
    let diemThangTruoc: Double
    let duocNhanVoucher: Bool
    let daNhanVoucher: Bool
    let tongNo: Double
    let tongChiTieuThangNay: Double
    let hang: String
    // Null nếu đã ở hạng cao nhất (Kim Cương) trong tháng này.
    let hangTiepTheo: String?
    let conLaiDeLenHang: Double
    // 0-1, tiến độ trong khoảng [ngưỡng hạng hiện tại, ngưỡng hangTiepTheo] — chỉ có ý nghĩa khi
    // hangTiepTheo != nil.
    let phanTramTienDoLenHang: Double
    let monHayMua: [FavoriteItem]
}

struct ViGiaoDich: Decodable, Identifiable {
    let id: String
    let soTienThayDoi: Double
    let soDuTruoc: Double
    let soDuSau: Double
    let tenLoai: String
    let hoaDonId: String?
    let thoiGian: String
    let ghiChu: String?
}

struct LyBiMatResult: Decodable {
    let hoaDonId: String
    let maHoaDon: String
    let tenSanPham: String
    let tenBienThe: String
    let giaThat: Double
    let giaTraTien: Double
    let tietKiem: Double
}

struct DatLyBiMatRequest: Encodable { let diaChiText: String; let ghiChu: String?; let clientOrderId: String? }
struct DanhGiaDonRequest: Encodable { let hoaDonId: String; let soSao: Int; let nhanXet: String? }

struct TheTem: Decodable {
    let tongDonLifetime: Int
    let mocThuong: Int
    let temHienTai: Int
    let duDieuKienDoiThuong: Bool
    let soLanDaDoiThuong: Int
}

struct GioiThieuInfo: Decodable { let maGioiThieu: String; let soNguoiDaGioiThieu: Int; let daDuocGioiThieu: Bool }
struct ApDungMaGioiThieuRequest: Encodable { let maGioiThieu: String }

struct SinhNhatInfo: Decodable { let ngaySinh: String?; let dangTrongThangSinhNhat: Bool; let daNhanQuaNamNay: Bool }
struct CapNhatNgaySinhRequest: Encodable { let ngaySinh: String }

struct DoiMatKhauRequest: Encodable { let matKhauCu: String; let matKhauMoi: String }

struct CapNhatTenHienThiRequest: Encodable { let tenHienThi: String? }

struct VongQuayResult: Decodable { let label: String; let soTienThuong: Double; let trung: Bool }

struct PushTokenRequest: Encodable { let expoPushToken: String? }
