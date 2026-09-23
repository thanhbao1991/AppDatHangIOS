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
    // Số ly (dòng đồ uống, không tính topping) tối thiểu — chỉ có ý nghĩa khi DieuKien=SoLuongToiThieu
    // nội bộ. nil với voucher loại khác. Xem VoucherKhaDungDto.SoLuongToiThieu.
    var soLuongToiThieu: Int?
    // true khi voucher CHỈ dùng được khi giỏ có ít nhất 1 dòng Size L (DieuKien=UpsizeMonMoi nội bộ) —
    // KHÔNG ảnh hưởng số tiền giảm (vẫn cố định soTienGiam như voucher thường), chỉ để CheckoutView tự
    // ẩn voucher này khi giỏ hàng không có Size L. Xem VoucherKhaDungDto.ChiApDungKhiCoSizeL.
    var chiApDungKhiCoSizeL: Bool = false
    // true khi voucher CHỈ dùng được khi giỏ có ít nhất 1 dòng topping (DieuKien=ToppingMienPhi nội
    // bộ) — KHÔNG ảnh hưởng số tiền giảm (vẫn cố định soTienGiam như voucher thường, khớp
    // UpsizeMonMoi). Xem VoucherKhaDungDto.ChiApDungKhiCoTopping.
    var chiApDungKhiCoTopping: Bool = false
    // true khi voucher CHỈ dùng được khi giỏ có ít nhất 1 dòng SẢN PHẨM khách CHƯA TỪNG đặt trước đây
    // (DieuKien=MonMoiTraiNghiem nội bộ) — cần đối chiếu sanPhamId từng dòng giỏ với danh sách
    // APIClient.getSanPhamDaTungDat() (CheckoutView tự tải), KHÔNG chỉ nhìn giỏ hiện tại như 2 cờ trên.
    // Xem VoucherKhaDungDto.ChiApDungKhiCoMonMoi.
    var chiApDungKhiCoMonMoi: Bool = false
    // true khi voucher CHỈ dùng được cho đơn tạo từ nút "Đặt lại" (DieuKien=DatLai nội bộ) — khác 3 cờ
    // trên (đều nhìn giỏ hàng hiện tại), cờ này CheckoutView tự biết ngay từ cart.laDatLai, không cần
    // tải thêm dữ liệu gì. Xem VoucherKhaDungDto.ChiApDungKhiDatLai.
    var chiApDungKhiDatLai: Bool = false

    /// Số tiền giảm thực tế cho đơn hiện tại — PhanTram tính trên tổng tiền hàng (làm tròn LÊN hàng
    /// nghìn đồng rồi chặn trần giamToiDa), SoTien (kể cả UpsizeMonMoi/ToppingMienPhi) thì cố định
    /// soTienGiam — khớp DatHangService.TinhSoTienGiam bên Backend.
    func soTienGiamThucTe(tongTienHang: Double, cartItems: [CartItem] = []) -> Double {
        guard loaiGiam == "PhanTram" else { return soTienGiam }
        let giam = ceil(tongTienHang * (phanTramGiam ?? 0) / 100 / 1000) * 1000
        if let giamToiDa, giamToiDa > 0 { return min(giam, giamToiDa) }
        return giam
    }

    /// Nhãn giảm giá dạng RATE (không phải tiền quy đổi cho 1 đơn cụ thể) — khớp
    /// VoucherCuaToi.nhanGiamGia, dùng làm headline ở sheet "Chọn voucher" (CheckoutView) để cùng 1
    /// voucher không hiện 2 con số khác nhau giữa tab Voucher và lúc đặt hàng.
    var nhanGiamGia: String {
        loaiGiam == "PhanTram" ? "-\(Int(phanTramGiam ?? 0))%" : "-\(formatTien(soTienGiam))"
    }

    /// "Tối đa Xđ" khi voucher % có trần giảm — khớp VoucherCuaToi.nhanGiamToiDa, hiện Y HỆT tab
    /// Voucher (không hiện số tiền quy đổi riêng cho đơn hiện tại).
    var nhanGiamToiDa: String? {
        guard loaiGiam == "PhanTram", let giamToiDa, giamToiDa > 0 else { return nil }
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
    let daSuDung: Bool
    // Có giá trị (vd 2) khi voucher cho phép dùng NHIỀU HƠN 1 lần/tài khoản (UpsizeMonMoi/
    // ToppingMienPhi) — nil với voucher loại khác (1 lần hoặc không giới hạn).
    var soLanToiDa: Int?
    // Số lần ĐÃ dùng — chỉ có ý nghĩa khi soLanToiDa != nil.
    var soLanDaDung: Int?
    // true = voucher CHƯA tới ngày bắt đầu, server gửi kèm để khách BIẾT TRƯỚC (vd voucher dịp lễ
    // hiện trước vài ngày). KHÔNG dùng được — server vẫn từ chối áp dụng, nên hiện dạng xem trước.
    var chuaBatDau: Bool = false
    // Ngày bắt đầu có hiệu lực, chuỗi ISO — server chỉ gửi khi chuaBatDau = true. Để String chứ KHÔNG
    // để Date: app dùng JSONDecoder() trần (không set dateDecodingStrategy) nên Date sẽ decode hỏng,
    // mà hỏng 1 field là hỏng CẢ struct -> mất sạch danh sách voucher. Mọi field ngày khác trong file
    // này cũng là String vì lý do đó.
    var ngayBatDau: String?

    /// "Từ 23/09" — nhãn cho voucher chưa tới ngày, nil với voucher dùng được ngay.
    var nhanSapDienRa: String? {
        guard chuaBatDau, let ngayBatDau else { return nil }
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd"
        inF.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let date = inF.date(from: String(ngayBatDau.prefix(10))) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "dd/MM"
        out.locale = Locale(identifier: "vi_VN")
        return "Từ \(out.string(from: date))"
    }

    /// "Dùng được tối đa 2 lần/tài khoản" hoặc "Đã dùng 1/2 lần" — chỉ có khi soLanToiDa != nil.
    var nhanSoLan: String? {
        guard let soLanToiDa else { return nil }
        let daDung = soLanDaDung ?? 0
        return daDung > 0 ? "Đã dùng \(daDung)/\(soLanToiDa) lần" : "Dùng được tối đa \(soLanToiDa) lần/tài khoản"
    }

    /// Nhãn giảm giá cho tab Ưu đãi — không có đơn cụ thể để tính số tiền thật cho voucher %,
    /// nên hiện "-X%" thay vì "-0đ" (khớp cách AppQuanLyIOS hiện cho staff).
    var nhanGiamGia: String {
        loaiGiam == "PhanTram" ? "-\(Int(phanTramGiam ?? 0))%" : "-\(formatTien(soTienGiam))"
    }

    /// "Tối đa Xđ" khi voucher % có trần giảm — nil khi không áp dụng (SoTien hoặc không giới hạn).
    var nhanGiamToiDa: String? {
        guard loaiGiam == "PhanTram", let giamToiDa, giamToiDa > 0 else { return nil }
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
    /// Giỏ hàng hiện tại đến từ nút "Đặt lại" (tab Hoá đơn) — dùng cho voucher DieuKien=DatLai. Xem
    /// CartStore.laDatLai/markDatLai().
    let laDatLai: Bool
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
    // SanPham gốc (khác sanPhamBienTheId là biến thể/size) — giữ lại khi "Đặt lại" để voucher
    // MonMoiTraiNghiem tự kiểm tra đúng "món mới" ở giỏ hàng mới. nil nếu dòng cũ chưa gắn.
    let sanPhamId: String?
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
        // Cố định navy (giá trị Theme.primary GỐC trước khi đổi theo hạng khách 2026-09-16) — màu
        // trạng thái đơn phải cố định như 3 trạng thái khác, không được ăn theo Theme.primary nữa vì
        // giờ nó đổi theo hạng (vàng/đen/xám...), làm badge "Đã xác nhận" lẫn với màu CTA/hạng.
        case .daXacNhan: return Color(red: 0x1E / 255, green: 0x4E / 255, blue: 0x8C / 255)
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
/// Voucher thưởng lên hạng (LenHangBac/Vang/KimCuong bên Backend) gắn với 1 mốc hạng cụ thể — xem
/// KhachHangViDto.VoucherHangHienTai/VoucherHangTiepTheo.
struct HangVoucherThuong: Decodable {
    let ten: String
    var loaiGiam: String = "SoTien"
    let soTienGiam: Double
    var phanTramGiam: Double?
    var giamToiDa: Double?

    /// "-10%" hoặc "-5.000đ" — cùng công thức nhanGiamGia của Voucher/VoucherCuaToi.
    var nhanGiamGia: String {
        loaiGiam == "PhanTram" ? "-\(Int(phanTramGiam ?? 0))%" : "-\(formatTien(soTienGiam))"
    }

    /// "(tối đa Xđ)" khi voucher % có trần giảm, nil khi không áp dụng.
    var nhanGiamToiDa: String? {
        guard loaiGiam == "PhanTram", let giamToiDa, giamToiDa > 0 else { return nil }
        return "tối đa \(formatTien(giamToiDa))"
    }
}

struct KhachHangVi: Decodable {
    let soDu: Double
    let diemThangNay: Double
    let diemThangTruoc: Double
    let duocNhanVoucher: Bool
    let daNhanVoucher: Bool
    let tongNo: Double
    let tongChiTieuThangNay: Double
    let hang: String
    // Hạng tính theo chi tiêu THÁNG TRƯỚC — chỉ để hiển thị tham khảo cạnh "Điểm tháng trước", KHÁC
    // hang (hạng đang xét trong tháng hiện tại, dùng cho card lớn + voucher).
    var hangThangTruoc: String = ""
    // Null nếu đã ở hạng cao nhất (Kim Cương) trong tháng này.
    let hangTiepTheo: String?
    let conLaiDeLenHang: Double
    // 0-1, tiến độ trong khoảng [ngưỡng hạng hiện tại, ngưỡng hangTiepTheo] — chỉ có ý nghĩa khi
    // hangTiepTheo != nil.
    let phanTramTienDoLenHang: Double
    // Voucher khớp ĐÚNG hạng hiện tại — có giá trị = khách ĐÃ ĐẠT hạng này tháng này, dùng được
    // tháng sau. Nil nếu hạng "Thành Viên" hoặc staff chưa bật voucher LenHang* cho mốc này.
    let voucherHangHienTai: HangVoucherThuong?
    // Voucher khớp hangTiepTheo — dùng cho câu mời "còn Xđ để nhận voucher Y".
    let voucherHangTiepTheo: HangVoucherThuong?
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

struct CongNoLichSu: Decodable, Identifiable {
    let hoaDonId: String
    let maHoaDon: String
    let ngayNo: String
    let thanhTien: Double
    let daThu: Double
    let conLai: Double
    let phanLoai: String
    let tenMonSummary: String
    let diaChiText: String?

    var id: String { hoaDonId }
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


struct SinhNhatInfo: Decodable { let ngaySinh: String?; let dangTrongThangSinhNhat: Bool; let daNhanQuaNamNay: Bool }
struct CapNhatNgaySinhRequest: Encodable { let ngaySinh: String }

struct DoiMatKhauRequest: Encodable { let matKhauCu: String; let matKhauMoi: String }

struct CapNhatTenHienThiRequest: Encodable { let tenHienThi: String? }

struct VongQuayResult: Decodable { let label: String; let soTienThuong: Double; let trung: Bool; var soLuotConLai: Int = 0 }

/// GET /dat-hang/vong-quay/thong-tin
struct VongQuayInfo: Decodable { let soLuotConLai: Int }

struct PushTokenRequest: Encodable { let expoPushToken: String? }
