import SwiftUI

/// Tab "Giỏ hàng" — CHỈ còn 1 card hoá đơn (chi tiết món) + nút "Đặt hàng" cố định dưới cùng, bấm mới
/// chuyển qua CheckoutView (địa chỉ + hình thức thanh toán). Tách ra từ file CheckoutView.swift cũ
/// (trước đây gộp cả 3 bước "Hoá đơn/Nhận hàng/Thanh toán" thành 1 timeline dài trong CÙNG tab) theo
/// yêu cầu tham khảo bố cục Shopee — 2 màn rõ ràng: xem giỏ trước, bấm "Đặt hàng" mới sang bước điền
/// địa chỉ/chọn thanh toán.
struct GioHangView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]
    var notificationBell: AnyView

    /// Catalog nạp riêng cho tab này (không dùng chung state với MenuView) — chỉ để dựng lại SanPham
    /// gốc khi khách bấm sửa 1 dòng trong giỏ (ProductPickerSheet cần đủ danh sách bienThe/topping).
    @State private var sanPhams: [SanPham] = []
    @State private var nhoms: [NhomSanPham] = []
    @State private var toppings: [Topping] = []
    @State private var editingItem: CartItem?
    /// true cho tới khi loadCatalog() nạp xong — chặn bấm sửa cho tới khi chắc chắn có catalog, xem
    /// openEdit() và ghi chú gốc ở CheckoutView.swift bản cũ (bài học race lúc mới mở tab).
    @State private var loadingCatalog = true

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Giỏ hàng", icon: "cart", centerTitle: true, trailing: notificationBell)

            if cart.items.isEmpty {
                Text("Giỏ hàng trống.").foregroundColor(Theme.textFaint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    cardRow(topExtra: 6) { cardBox { cartCardContent } }
                }
                .cardListBackground()
                bottomBar
            }
        }
        .task {
            // Ép trần thời gian chờ (8s) — lần mở app ĐẦU TIÊN (chưa cache gì) request có thể treo
            // lâu hơn bình thường, không để dòng món mờ (loadingCatalog=true) "mãi không hết".
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadCatalog() }
                group.addTask { try? await Task.sleep(nanoseconds: 8_000_000_000) }
                await group.next()
                group.cancelAll()
            }
            loadingCatalog = false
        }
        .sheet(item: $editingItem) { item in
            let realSp = sanPham(for: item)
            let sp = realSp ?? fallbackSanPham(for: item)
            let toppingChoices = realSp != nil ? toppings : item.toppings.map { Topping(id: $0.id, ten: $0.ten, gia: $0.gia, ngungBan: false) }
            ProductPickerSheet(
                sanPham: sp,
                toppings: toppingChoices,
                isThuocLa: thuocLaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                khongChoKhongDa: khongChoKhongDaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                showTraNote: caPheNhomIds.contains(sp.nhomSanPhamId ?? ""),
                existing: item,
                onConfirm: { bienThe, soLuong, ghiChu, toppings in
                    if soLuong <= 0 {
                        cart.removeItem(item.id)
                    } else {
                        cart.updateItem(item.id, sanPhamBienTheId: bienThe.id, tenBienThe: bienThe.tenBienThe, giaBan: bienThe.giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings)
                    }
                }
            ) { editingItem = nil }
        }
    }

    private var cartCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hoá đơn").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                Spacer()
                qtyCountBadge
            }
            Divider()
            ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                itemRow(item)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tạm tính").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                Text(formatTien(cart.totalPrice)).font(.system(size: 18, weight: .bold))
            }
            Spacer()
            Button {
                path.append(.checkout)
            } label: {
                Text("Đặt hàng").fontWeight(.bold).frame(minWidth: 120)
            }
            .buttonStyle(.gradientProminent)
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(Color.white)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .top)
    }

    private var qtyCountBadge: some View {
        Text("\(cart.totalCount) ly")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Theme.primary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.primaryTint)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func itemThumbnail(_ item: CartItem) -> some View {
        // Dòng giỏ có thể không mang hinhAnh (giỏ lưu từ bản cũ, "Đặt lại" từ hoá đơn cũ) — rơi về
        // ảnh trong catalog, khớp với sheet sửa món vốn đã dùng SanPham thật từ catalog.
        let sp = sanPham(for: item)
        if let hinhAnh = item.hinhAnh ?? sp?.hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            let ten = sp.flatMap { sp in nhoms.first { $0.id == sp.nhomSanPhamId }?.ten }
            RoundedRectangle(cornerRadius: 8).fill(Theme.primaryTint).frame(width: 36, height: 36)
                .overlay(Text(ten.flatMap { Theme.nhomIcons[$0] } ?? Theme.defaultNhomIcon).font(.system(size: 18)))
        }
    }

    /// Nhóm chứa thuốc lá/sinh tố/đá xay — cần cho ProductPickerSheet lúc sửa, khớp y hệt logic bên
    /// MenuView.
    private var thuocLaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Thuốc lá" }.map(\.id))
    }

    private var khongChoKhongDaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Sinh Tố" || $0.ten == "Đá Xay" }.map(\.id))
    }

    private var caPheNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Cà Phê" }.map(\.id))
    }

    /// Dựng lại SanPham gốc chứa biến thể của 1 dòng trong giỏ — nil nếu món đã bị xoá/ẩn khỏi menu.
    /// Khớp theo id trước, rồi rơi về khớp theo TÊN nếu id không tìm thấy (đơn "Đặt lại" copy id cũ
    /// có thể không còn tồn tại nếu biến thể đã sửa/tạo lại trên Desktop).
    private func sanPham(for item: CartItem) -> SanPham? {
        sanPhams.first { $0.bienThe.contains { $0.id == item.sanPhamBienTheId } }
            ?? sanPhams.first { $0.ten == item.tenSanPham }
    }

    /// Dùng khi không dựng lại được SanPham thật từ catalog — tự tạo 1 SanPham "tối giản" đủ để sheet
    /// sửa mở ra sửa được số lượng/ghi chú/topping đã chọn.
    private func fallbackSanPham(for item: CartItem) -> SanPham {
        SanPham(
            id: item.sanPhamBienTheId, ten: item.tenSanPham, ngungBan: false, nhomSanPhamId: nil,
            hinhAnh: item.hinhAnh,
            bienThe: [SanPhamBienThe(id: item.sanPhamBienTheId, tenBienThe: item.tenBienThe, giaBan: item.giaBan, macDinh: true)],
            timKiem: nil, storeFoodId: nil, khongLenStore: false
        )
    }

    private func loadCatalog() async {
        async let spTask = APIClient.shared.getSanPhamList()
        async let nhomTask = APIClient.shared.getNhomSanPhamList()
        async let topTask = APIClient.shared.getToppingList()
        let (sp, nhom, top) = await (spTask, nhomTask, topTask)
        sanPhams = sp
        nhoms = nhom
        toppings = top
    }

    private func openEdit(_ item: CartItem) {
        guard !loadingCatalog else { return }
        editingItem = item
    }

    /// Xoá món: nút X ngay dưới số tiền, HOẶC kéo Stepper "Số lượng" về 0 trong sheet sửa. Phần còn
    /// lại của dòng dùng .onTapGesture để mở sửa; nút X cần .contentShape(Rectangle())+.buttonStyle(.plain)
    /// để thắng .onTapGesture của view cha (đã xác nhận qua test thật).
    private func itemRow(_ item: CartItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            itemThumbnail(item)
            Text("\(item.soLuong)")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.tenSanPham)\(bienTheSuffix(item.tenBienThe))").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    if !item.toppings.isEmpty {
                        Text(item.toppings.map { t in
                            let label = t.soLuong > 1 ? "\(t.ten) x\(t.soLuong)" : t.ten
                            return "\(label) +\(formatTienShort(t.gia * Double(t.soLuong)))"
                        }.joined(separator: ", "))
                            .font(.system(size: 12)).foregroundColor(Theme.primary)
                    }
                    if let itemGhiChu = item.ghiChu, !itemGhiChu.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(itemGhiChu).font(.system(size: 12)).italic().foregroundColor(Theme.warning)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTien(item.thanhTien)).font(.system(size: 14, weight: .semibold))
                    Button {
                        cart.removeItem(item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.danger)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // KHÔNG làm mờ cả dòng theo loadingCatalog nữa — tên/số lượng/giá của dòng giỏ lấy thẳng từ
        // CartItem (đã có sẵn, không phụ thuộc catalog), chỉ riêng thao tác SỬA (openEdit) mới cần
        // đợi catalog xong. Trước đây mờ cả dòng dù dữ liệu hiển thị đã đủ, gây cảm giác "giỏ hàng bị
        // lỗi/chưa tải" mỗi khi vừa chuyển từ tab Thực đơn sang lúc mạng chậm.
        .contentShape(Rectangle())
        .onTapGesture { openEdit(item) }
    }
}
