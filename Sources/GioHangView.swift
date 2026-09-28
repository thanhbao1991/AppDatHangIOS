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
    @State private var showVoucherSheet = false

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Giỏ hàng", icon: "cart", centerTitle: true, trailing: notificationBell)

            if cart.items.isEmpty {
                Text("Giỏ hàng trống.").foregroundColor(Theme.textFaint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // 2026-09-26: đổi sang dạng PHẲNG (List(.plain) + đường kẻ mặc định) giống Đơn hàng/
                // Lịch sử Xu/Voucher — bỏ cardBox/cardRow/cardListBackground (Theme.swift) riêng cho
                // màn này, các tab khác vẫn dùng nguyên style card chung đó.
                List {
                    ForEach(cart.items) { item in
                        itemRow(item)
                    }
                }
                .listStyle(.plain)
                bottomBar
            }
        }
        .task {
            await loadCatalog()
            await cart.loadUuDaiIfNeeded()
        }
        .sheet(isPresented: $showVoucherSheet) {
            VoucherPickerSheet(
                vouchers: cart.vouchers, duDieuKien: cart.voucherDuDieuKien,
                giaTriGiam: { $0.soTienGiamThucTe(tongTienHang: cart.totalPrice, cartItems: cart.items) },
                selected: $cart.selectedVoucher,
                onClose: { showVoucherSheet = false },
                onRetry: { await cart.reloadVouchers() }
            )
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

    private var bottomBar: some View {
        VStack(spacing: 0) {
            uuDaiSection
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tạm tính").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                    // Số tiền tự "đếm chạy" qua từng số trung gian khi áp voucher/đổi Xu (xem
                    // AnimatableTienText — Theme.swift) đã tự nói lên "có giảm giá" qua animation, nên
                    // KHÔNG cần hiện thêm giá gốc gạch ngang bên cạnh nữa (feedback 2026-09-27) — chỉ
                    // còn đúng 1 số duy nhất.
                    AnimatableTienText(value: tongSauGiam)
                        .font(.system(size: 18, weight: .bold))
                        .animation(.easeOut(duration: 0.6), value: tongSauGiam)
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
        }
        .background(Color.white)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .top)
    }

    private var voucherGiam: Double { cart.voucherGiam(tongTienHang: cart.totalPrice) }

    /// Tổng tiền hàng sau khi trừ voucher — nền cho bước tính trừ Xu bên dưới (chưa gồm phí ship, màn
    /// này không biết ship vì địa chỉ chọn ở bước Thanh toán).
    private var tongSauVoucher: Double { max(cart.totalPrice - voucherGiam, 0) }

    /// Số Xu THỰC SỰ trừ được nếu bật "Dùng Xu" — khớp DatHangService.DatMonAsync/
    /// CheckoutView.soTienDungXu bên backend (trần 50% đã bỏ 2026-09-27, Xu trả tối đa 100% đơn).
    /// Thiếu phí ship (chưa có ở bước Giỏ hàng) nên đây là số ước lượng, Thanh toán mới là số cuối
    /// cùng — nhưng đủ để khách THẤY rõ bật Xu có trừ tiền, đúng phản hồi "bật xu chưa thấy trừ tiền".
    private var xuGiam: Double { cart.dungXu ? min(cart.soDuXu, tongSauVoucher) : 0 }
    private var tongSauGiam: Double { max(tongSauVoucher - xuGiam, 0) }
    /// Bố cục tham khảo ShopeeFood (2026-09-27): 1 dòng bo góc riêng "Đã áp dụng voucher" mở sheet
    /// chọn voucher, tách hẳn khỏi dòng "Dùng Xu" bên dưới thay vì gộp chung 1 card như bản cũ — Xu
    /// luôn hiện, không phụ thuộc đã chọn voucher hay chưa. Toggle Xu disable khi số dư = 0.
    @ViewBuilder
    private var uuDaiSection: some View {
        VStack(spacing: 10) {
            Button { showVoucherSheet = true } label: {
                HStack {
                    // Ghi rõ giá trị giảm ngay sau khi chọn (feedback 2026-09-27) thay vì chỉ đếm số
                    // lượng ưu đãi trần trụi như bản trước.
                    if voucherGiam > 0 {
                        Text("Đã áp dụng voucher (-\(formatTien(voucherGiam)))")
                            .font(.system(size: 14)).foregroundColor(Theme.textMuted)
                    } else {
                        Text("Chưa áp dụng voucher")
                            .font(.system(size: 14)).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Text("Chọn voucher").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.primary)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.primary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle(isOn: $cart.dungXu) {
                HStack(spacing: 8) {
                    Theme.xuIcon(22)
                    // 1 Xu = 1đ (quy đổi thẳng) — hiện cả 2 đơn vị để khách thấy rõ Xu quy ra tiền thật
                    // bao nhiêu, khớp yêu cầu "xu ~ đ". Không chèn khoảng trắng trước "đ" (feedback
                    // 2026-09-27) — formatTien đã tự ghép liền số+đ.
                    Text("Đổi \(formatXu(cart.soDuXu)) (~\(formatTien(cart.soDuXu)))")
                        .font(.system(size: 14)).foregroundColor(.primary)
                }
            }
            .tint(Theme.primary)
            .disabled(cart.soDuXu <= 0)
        }
        .padding(.horizontal).padding(.vertical, 10)
    }

    @ViewBuilder
    private func itemThumbnail(_ item: CartItem) -> some View {
        // Dòng giỏ có thể không mang hinhAnh (giỏ lưu từ bản cũ, "Đặt lại" từ hoá đơn cũ) — rơi về
        // ảnh trong catalog, khớp với sheet sửa món vốn đã dùng SanPham thật từ catalog.
        let sp = sanPham(for: item)
        if let hinhAnh = item.hinhAnh ?? sp?.hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            let ten = sp.flatMap { sp in nhoms.first { $0.id == sp.nhomSanPhamId }?.ten }
            RoundedRectangle(cornerRadius: 10).fill(Theme.primaryTint).frame(width: 56, height: 56)
                .overlay(Text(ten.flatMap { Theme.nhomIcons[$0] } ?? Theme.defaultNhomIcon).font(.system(size: 24)))
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
            timKiem: nil, storeFoodId: nil, khongLenStore: false, noiBat: false
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
        // KHÔNG chặn theo loadingCatalog nữa — .sheet bên trên đã tự rơi về fallbackSanPham(for:) khi
        // catalog thật chưa có/chưa kịp tải (sanPham(for:) trả nil), đủ để sửa số lượng/ghi chú/topping
        // đã chọn ngay lập tức. Trước đây chặn cứng ở đây khiến bấm "sửa" không phản hồi gì (không mờ,
        // không lỗi, không gì cả) nếu loadCatalog() của CHÍNH tab Giỏ hàng chậm/kẹt — mà theo quan sát
        // thực tế, nó có thể kẹt rất lâu, không chỉ tới khi tab Thực đơn tải menu xong mới tự thông.
        editingItem = item
    }

    /// Sửa size/topping/ghi chú: chạm vào ẢNH hoặc phần TÊN món (mở sheet sửa) — trước đây chỉ vùng
    /// tên bắt được chạm, bấm trúng ảnh không phản hồi gì (feedback 2026-09-27). Sửa NHANH số lượng:
    /// dùng luôn bộ +/- ở góc phải (tham khảo Long Châu) — không cần mở sheet chỉ để đổi số lượng nữa.
    /// Nút +/- cần .contentShape(Rectangle())+.buttonStyle(.plain) để thắng .onTapGesture của view cha
    /// (cùng bài học nút X bản cũ, đã xác nhận qua test thật).
    private func itemRow(_ item: CartItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                itemThumbnail(item)
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
            }
            // KHÔNG làm mờ cả dòng theo loadingCatalog nữa — tên/số lượng/giá của dòng giỏ lấy thẳng
            // từ CartItem (đã có sẵn, không phụ thuộc catalog), chỉ riêng thao tác SỬA (openEdit) mới
            // cần đợi catalog xong. Trước đây mờ cả dòng dù dữ liệu hiển thị đã đủ, gây cảm giác "giỏ
            // hàng bị lỗi/chưa tải" mỗi khi vừa chuyển từ tab Thực đơn sang lúc mạng chậm.
            .contentShape(Rectangle())
            .onTapGesture { openEdit(item) }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatTien(item.thanhTien)).font(.system(size: 14, weight: .semibold))
                quantityStepper(item)
            }
        }
        .padding(.vertical, 6)
    }

    /// Bộ +/- gọn kiểu Long Châu — nút trái đổi hẳn sang icon thùng rác khi số lượng còn 1 (bấm sẽ
    /// xoá cả dòng, khớp hành vi CartStore.setQuantity tự xoá khi về 0) thay vì vẫn hiện dấu "-" rồi
    /// mới xoá ở lượt bấm kế tiếp — rõ ý hơn cho khách.
    private func quantityStepper(_ item: CartItem) -> some View {
        HStack(spacing: 0) {
            Button {
                cart.setQuantity(item.id, soLuong: item.soLuong - 1)
            } label: {
                Image(systemName: item.soLuong <= 1 ? "trash" : "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(item.soLuong <= 1 ? Theme.danger : Theme.primary)
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            Text("\(item.soLuong)")
                .font(.system(size: 13, weight: .bold))
                .frame(minWidth: 22)
            Button {
                cart.setQuantity(item.id, soLuong: item.soLuong + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.primary)
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .background(Theme.bg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.divider))
    }
}
