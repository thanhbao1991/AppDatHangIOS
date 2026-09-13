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

    var donGia: Double { giaBan + toppings.reduce(0) { $0 + $1.gia * Double($1.soLuong) } }
    var thanhTien: Double { donGia * Double(soLuong) }
}

@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = [] {
        didSet { persist() }
    }

    /// Giỏ hàng lưu qua UserDefaults (JSON) — trước đây thuần in-memory nên tắt app (không chỉ gỡ
    /// cài) là mất sạch giỏ, khách đang chọn dở món phải làm lại từ đầu.
    private static let storageKey = "cart.items.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([CartItem].self, from: data) else { return }
        items = saved
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    var totalCount: Int { items.reduce(0) { $0 + $1.soLuong } }
    var totalPrice: Double { items.reduce(0) { $0 + $1.thanhTien } }

    func addItem(sanPhamBienTheId: String, tenSanPham: String, tenBienThe: String, giaBan: Double, soLuong: Int, ghiChu: String?, toppings: [CartTopping], hinhAnh: String? = nil) {
        items.append(CartItem(id: UUID(), sanPhamBienTheId: sanPhamBienTheId, tenSanPham: tenSanPham, tenBienThe: tenBienThe, giaBan: giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings, hinhAnh: hinhAnh))
    }

    func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// soLuong <= 0 xoá luôn dòng — khớp hành vi nút "-" ở CheckoutScreen khi về 0.
    func setQuantity(_ id: UUID, soLuong: Int) {
        if soLuong <= 0 { removeItem(id); return }
        if let idx = items.firstIndex(where: { $0.id == id }) { items[idx].soLuong = soLuong }
    }

    /// Sửa lại 1 dòng đã có trong giỏ (đổi size/topping/ghi chú/số lượng) — dùng khi khách bấm vào
    /// món ở CheckoutView để mở lại ProductPickerSheet ở chế độ sửa, thay vì thêm dòng mới.
    func updateItem(_ id: UUID, sanPhamBienTheId: String, tenBienThe: String, giaBan: Double, soLuong: Int, ghiChu: String?, toppings: [CartTopping]) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx] = CartItem(id: id, sanPhamBienTheId: sanPhamBienTheId, tenSanPham: items[idx].tenSanPham, tenBienThe: tenBienThe, giaBan: giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings, hinhAnh: items[idx].hinhAnh)
    }

    func clear() { items.removeAll() }
}
