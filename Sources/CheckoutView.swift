import SwiftUI
import CoreLocation

/// Port từ CheckoutScreen.tsx — giỏ hàng + địa chỉ giao (GPS/kéo ghim MapKit) + đặt hàng.
struct CheckoutView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]
    var notificationBell: AnyView

    @State private var ghiChu = ""
    @State private var diaChi = ""
    @State private var savedDiaChi: [DiaChiKhachHang] = []
    @State private var loading = false
    @State private var error = ""
    @State private var clientOrderId: String?

    @State private var coord: CLLocationCoordinate2D?
    @State private var locLoading = false
    @State private var locError = ""
    @State private var ship: UocTinhShip?

    /// Catalog nạp riêng cho CheckoutView (không dùng chung state với MenuView) — chỉ để dựng lại
    /// SanPham gốc khi khách bấm sửa 1 dòng trong giỏ (ProductPickerSheet cần đủ danh sách bienThe/
    /// topping để hiện lại UI chọn, giống lúc thêm mới ở MenuView).
    @State private var sanPhams: [SanPham] = []
    @State private var nhoms: [NhomSanPham] = []
    @State private var toppings: [Topping] = []
    @State private var editingItem: CartItem?

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Giỏ hàng", center: cart.items.isEmpty ? nil : AnyView(qtyBadge), trailing: notificationBell)

            List {
                if !cart.items.isEmpty {
                    cardRow(topExtra: 6) { cartItemsCard }
                    cardRow { addressBox }
                    cardRow { footerCard }
                } else {
                    Text("Giỏ hàng trống.").foregroundColor(Theme.textFaint).frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .cardListBackground()
        }
        .task {
            await loadDiaChi()
            await loadCatalog()
        }
        .sheet(item: $editingItem) { item in
            if let sp = sanPham(for: item) {
                ProductPickerSheet(
                    sanPham: sp,
                    toppings: toppings,
                    isThuocLa: thuocLaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                    khongChoKhongDa: khongChoKhongDaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                    existing: item,
                    onConfirm: { bienThe, soLuong, ghiChu, toppings in
                        cart.updateItem(item.id, sanPhamBienTheId: bienThe.id, tenBienThe: bienThe.tenBienThe, giaBan: bienThe.giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings)
                    }
                ) { editingItem = nil }
            }
        }
    }

    /// Badge "X Ly" giữa thanh tiêu đề — nền trắng nổi trên gradient navy của TitleBar, gọn hơn số
    /// đặt cạnh icon giỏ vì tab Giỏ hàng đã tự là màn hình giỏ, không cần icon nhắc lại.
    private var qtyBadge: some View {
        Text("\(cart.totalCount) Ly")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Theme.primary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color.white)
            .clipShape(Capsule())
    }

    /// Card 1: chi tiết hoá đơn — mỗi dòng bấm vào (trừ vùng số lượng/xoá) mở lại ProductPickerSheet
    /// ở chế độ sửa.
    private var cartItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chi tiết hoá đơn").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
            ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                itemRow(item)
                if index < cart.items.count - 1 { Divider() }
            }
        }
        .cardBoxStyle()
    }

    private var addressBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Giao đến").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
            TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            if !savedDiaChi.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(savedDiaChi) { d in
                            Button {
                                diaChi = d.diaChi
                                if let lat = d.lat, let long = d.long {
                                    Task { await applyCoord(CLLocationCoordinate2D(latitude: lat, longitude: long)) }
                                }
                            } label: {
                                Text((d.isDefault ? "★ " : "") + d.diaChi)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(diaChi == d.diaChi ? Theme.primaryTint : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(diaChi == d.diaChi ? Theme.primary : Theme.divider))
                            }
                            .foregroundColor(diaChi == d.diaChi ? Theme.primary : Theme.textMuted)
                        }
                    }
                }
            }

            Button {
                Task { await dungViTriHienTai() }
            } label: {
                HStack {
                    Spacer()
                    if locLoading { ProgressView() } else { Text("📍 Dùng vị trí hiện tại (tính phí ship chính xác)").font(.system(size: 13, weight: .semibold)) }
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
            .disabled(locLoading)

            if !locError.isEmpty { Text(locError).font(.system(size: 12)).foregroundColor(Theme.danger) }

            if let coord, let ship {
                DeliveryMapView(
                    shopCoordinate: CLLocationCoordinate2D(latitude: ship.shopLat, longitude: ship.shopLong),
                    deliveryCoordinate: coord,
                    routePoints: (ship.tuyenDuong ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.long) },
                    onDragEnd: { newCoord in Task { await applyCoord(newCoord) } }
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("Khoảng cách ~\(String(format: "%.1f", ship.khoangCachKm))km").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    Spacer()
                    Text("Phí ship: \(formatTien(ship.phiShip))").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
                }
            }
        }
        .cardBoxStyle()
    }

    /// Card cuối: ghi chú + tạm tính + nút đặt hàng.
    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Ghi chú cho đơn hàng (không bắt buộc)", text: $ghiChu)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Tạm tính")
                Spacer()
                Text(formatTien(cart.totalPrice + (ship?.phiShip ?? 0))).fontWeight(.bold)
            }
            if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundColor(Theme.danger) }
            Button {
                Task { await datHang() }
            } label: {
                HStack {
                    Spacer()
                    if loading { ProgressView().tint(.white) } else { Text("Đặt hàng").fontWeight(.bold) }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .disabled(loading || diaChi.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .cardBoxStyle()
    }

    /// Nhóm chứa thuốc lá/sinh tố/đá xay — cần cho ProductPickerSheet lúc sửa (cảnh báo 18 tuổi,
    /// disable "Không đá"), khớp y hệt logic bên MenuView.
    private var thuocLaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Thuốc lá" }.map(\.id))
    }

    private var khongChoKhongDaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Sinh Tố" || $0.ten == "Đá Xay" }.map(\.id))
    }

    /// Dựng lại SanPham gốc chứa biến thể của 1 dòng trong giỏ — nil nếu món đã bị xoá/ẩn khỏi menu
    /// (khi đó dòng vẫn hiện bình thường trong giỏ nhưng không bấm sửa được, chỉ xoá được).
    private func sanPham(for item: CartItem) -> SanPham? {
        sanPhams.first { $0.bienThe.contains { $0.id == item.sanPhamBienTheId } }
    }

    private func itemRow(_ item: CartItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if sanPham(for: item) != nil { editingItem = item }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.tenSanPham) (\(item.tenBienThe))").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    if !item.toppings.isEmpty {
                        Text("+ " + item.toppings.map { $0.soLuong > 1 ? "\($0.ten) x\($0.soLuong)" : $0.ten }.joined(separator: ", ")).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    }
                    if let itemGhiChu = item.ghiChu, !itemGhiChu.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(itemGhiChu).font(.system(size: 12)).foregroundColor(Theme.textFaint).lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(formatTien(item.thanhTien)).font(.system(size: 14, weight: .semibold))
                HStack(spacing: 10) {
                    Button { cart.setQuantity(item.id, soLuong: item.soLuong - 1) } label: { Image(systemName: "minus.circle") }
                    Text("\(item.soLuong)").fontWeight(.bold)
                    Button { cart.setQuantity(item.id, soLuong: item.soLuong + 1) } label: { Image(systemName: "plus.circle") }
                    Button { cart.removeItem(item.id) } label: { Image(systemName: "xmark").foregroundColor(Theme.danger) }
                }
                .tint(Theme.primary)
            }
        }
    }

    private func loadDiaChi() async {
        let list = await APIClient.shared.getDiaChiList()
        savedDiaChi = list
        if let macDinh = list.first(where: \.isDefault) {
            diaChi = macDinh.diaChi
            if let lat = macDinh.lat, let long = macDinh.long {
                await applyCoord(CLLocationCoordinate2D(latitude: lat, longitude: long))
            }
        }
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

    private func applyCoord(_ c: CLLocationCoordinate2D) async {
        coord = c
        ship = nil
        let result = await APIClient.shared.uocTinhShip(lat: c.latitude, long: c.longitude)
        if result.isSuccess { ship = result.data }
    }

    private func dungViTriHienTai() async {
        locError = ""
        locLoading = true
        defer { locLoading = false }
        guard let location = await LocationHelper.shared.requestLocation() else {
            locError = "Không lấy được vị trí. Bạn có thể kéo ghim trên bản đồ hoặc nhập địa chỉ tay."
            return
        }
        await applyCoord(location.coordinate)
        if let address = await LocationHelper.shared.reverseGeocode(location) {
            diaChi = address
        }
    }

    private func datHang() async {
        guard !cart.items.isEmpty, !diaChi.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Vui lòng nhập địa chỉ giao hàng."
            return
        }
        loading = true; error = ""
        defer { loading = false }
        if clientOrderId == nil { clientOrderId = UUID().uuidString }
        let items = cart.items.map { DatMonItem(sanPhamBienTheId: $0.sanPhamBienTheId, soLuong: $0.soLuong, ghiChu: $0.ghiChu, toppings: $0.toppings.map { DatMonToppingItem(toppingId: $0.id, soLuong: $0.soLuong) }) }
        let result = await APIClient.shared.datMon(
            items: items, diaChiText: diaChi.trimmingCharacters(in: .whitespaces), ghiChu: ghiChu.isEmpty ? nil : ghiChu,
            soDienThoaiText: nil, deliveryLat: coord?.latitude, deliveryLong: coord?.longitude, clientOrderId: clientOrderId
        )
        if result.isSuccess, let data = result.data {
            clientOrderId = nil
            cart.clear()
            path.append(.thanhToan(hoaDonId: data.id))
        } else {
            error = result.message ?? "Đặt hàng thất bại."
        }
    }
}
