import Foundation

/// Port từ CartContext.tsx (bản RN cũ).
struct CartTopping: Identifiable, Hashable, Codable { let id: String; let ten: String; let gia: Double; let soLuong: Int }

struct CartItem: Identifiable, Hashable, Codable {
    let id: UUID
    let sanPhamBienTheId: String
    let tenSanPham: String
    let tenBienThe: String
    let giaBan: Double
    var soLuong: Int
    var ghiChu: String?
    let toppings: [CartTopping]
    /// Ảnh menu — hiện thumbnail ở CheckoutView giống itemRow bên HoaDonDetailView (AppQuanLyIOS).
    let hinhAnh: String?
    /// SanPham gốc (khác sanPhamBienTheId là biến thể/size) — dùng để CheckoutView tự kiểm tra voucher
    /// MonMoiTraiNghiem (giỏ có món khách CHƯA TỪNG đặt) mà không cần tải cả menu. nil nếu không rõ
    /// (không nên xảy ra ở luồng thêm mới từ MenuView, chỉ có thể ở dữ liệu giỏ cũ trước bản này).
    var sanPhamId: String?

    var donGia: Double { giaBan + toppings.reduce(0) { $0 + $1.gia * Double($1.soLuong) } }
    var thanhTien: Double { donGia * Double(soLuong) }
}

@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = [] {
        didSet { persist() }
    }
    /// true khi giỏ hàng HIỆN TẠI được tạo nguyên vẹn từ nút "Đặt lại" (tab Hoá đơn), chưa bị sửa tay
    /// gì thêm — dùng cho voucher DieuKien=DatLai (Voucher.chiApDungKhiDatLai). Mọi thao tác sửa giỏ
    /// (thêm/xoá/sửa dòng) đều reset về false để khách không "mượn" 1 lần đặt lại rồi tự ý thêm bớt
    /// vẫn tính là đặt lại.
    @Published private(set) var laDatLai = false {
        didSet { persist() }
    }

    /// Giỏ hàng lưu qua UserDefaults (JSON) — trước đây thuần in-memory nên tắt app (không chỉ gỡ
    /// cài) là mất sạch giỏ, khách đang chọn dở món phải làm lại từ đầu.
    private static let storageKey = "cart.items.v1"
    private static let laDatLaiKey = "cart.laDatLai.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([CartItem].self, from: data) else { return }
        items = saved
        laDatLai = UserDefaults.standard.bool(forKey: Self.laDatLaiKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        UserDefaults.standard.set(laDatLai, forKey: Self.laDatLaiKey)
    }

    var totalCount: Int { items.reduce(0) { $0 + $1.soLuong } }
    var totalPrice: Double { items.reduce(0) { $0 + $1.thanhTien } }

    func addItem(sanPhamBienTheId: String, tenSanPham: String, tenBienThe: String, giaBan: Double, soLuong: Int, ghiChu: String?, toppings: [CartTopping], hinhAnh: String? = nil, sanPhamId: String? = nil) {
        items.append(CartItem(id: UUID(), sanPhamBienTheId: sanPhamBienTheId, tenSanPham: tenSanPham, tenBienThe: tenBienThe, giaBan: giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings, hinhAnh: hinhAnh, sanPhamId: sanPhamId))
        laDatLai = false
    }

    func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        laDatLai = false
    }

    /// soLuong <= 0 xoá luôn dòng — khớp hành vi nút "-" ở CheckoutScreen khi về 0.
    func setQuantity(_ id: UUID, soLuong: Int) {
        if soLuong <= 0 { removeItem(id); return }
        if let idx = items.firstIndex(where: { $0.id == id }) { items[idx].soLuong = soLuong }
        laDatLai = false
    }

    /// Sửa lại 1 dòng đã có trong giỏ (đổi size/topping/ghi chú/số lượng) — dùng khi khách bấm vào
    /// món ở CheckoutView để mở lại ProductPickerSheet ở chế độ sửa, thay vì thêm dòng mới.
    func updateItem(_ id: UUID, sanPhamBienTheId: String, tenBienThe: String, giaBan: Double, soLuong: Int, ghiChu: String?, toppings: [CartTopping]) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx] = CartItem(id: id, sanPhamBienTheId: sanPhamBienTheId, tenSanPham: items[idx].tenSanPham, tenBienThe: tenBienThe, giaBan: giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings, hinhAnh: items[idx].hinhAnh, sanPhamId: items[idx].sanPhamId)
        laDatLai = false
    }

    /// Đánh dấu giỏ hàng HIỆN TẠI đến nguyên vẹn từ nút "Đặt lại" — gọi NGAY SAU khi nạp xong toàn bộ
    /// dòng hàng của đơn cũ (addItem() ở trên tự reset về false, nên phải gọi hàm này SAU CÙNG).
    func markDatLai() {
        laDatLai = true
    }

    func clear() {
        items.removeAll()
        laDatLai = false
    }
}
