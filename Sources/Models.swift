import Foundation

// Port 1:1 từ src/api.ts (bản RN cũ, xem lịch sử git trước commit chuyển native) — field name phải
// khớp tuyệt đối JSON backend trả về (không có CodingKeys riêng, tên property Swift = tên field JSON).

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
}

struct NhomSanPham: Decodable, Identifiable { let id: String; let ten: String }
struct Topping: Decodable, Identifiable { let id: String; let ten: String; let gia: Double; let ngungBan: Bool }

// ---- Đặt món ----

struct DatMonItem: Encodable { let sanPhamBienTheId: String; let soLuong: Int; let ghiChu: String?; let toppingIds: [String] }
struct DatMonRequest: Encodable {
    let items: [DatMonItem]
    let ghiChu: String?
    let diaChiText: String
    let soDienThoaiText: String?
    let deliveryLat: Double?
    let deliveryLong: Double?
    let clientOrderId: String?
}
struct DatMonResponse: Decodable { let id: String; let thanhTien: Double }

struct UocTinhShipRequest: Encodable { let lat: Double; let long: Double }
struct TuyenDuongPoint: Decodable { let lat: Double; let long: Double }
struct UocTinhShip: Decodable {
    let khoangCachKm: Double
    let phiShip: Double
    let shopLat: Double
    let shopLong: Double
    let tuyenDuong: [TuyenDuongPoint]?
}

struct DonHangKhachItemTopping: Decodable, Identifiable, Hashable {
    let toppingId: String
    let ten: String
    let gia: Double
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

enum TrangThaiDon: String, Decodable { case choXacNhan = "ChoXacNhan", daXacNhan = "DaXacNhan", dangGiao = "DangGiao", hoanTat = "HoanTat" }

struct DonHangKhach: Decodable, Identifiable {
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
}

// ---- Địa chỉ ----

struct DiaChiKhachHang: Decodable, Identifiable {
    let id: String
    let diaChi: String
    let isDefault: Bool
    let lat: Double?
    let long: Double?
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
    let tongChiTieuLifetime: Double
    let hang: String
    let monHayMua: [FavoriteItem]
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

struct VongQuayResult: Decodable { let label: String; let soTienThuong: Double; let trung: Bool }

struct PushTokenRequest: Encodable { let expoPushToken: String? }
