import SwiftUI
import CoreLocation

/// Port từ CheckoutScreen.tsx — giỏ hàng + địa chỉ giao (GPS/kéo ghim MapKit) + đặt hàng.
struct CheckoutView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]

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

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Giỏ hàng")

            List {
                if !cart.items.isEmpty {
                    Section {
                        addressBox
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    ForEach(cart.items) { item in
                        itemRow(item)
                    }

                    Section {
                        TextField("Ghi chú cho đơn hàng (không bắt buộc)", text: $ghiChu)
                        HStack {
                            Text("Tạm tính")
                            Spacer()
                            Text(formatTien(cart.totalPrice + (ship?.phiShip ?? 0))).fontWeight(.bold)
                        }
                        if !error.isEmpty { Text(error).foregroundColor(Theme.danger) }
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
                } else {
                    Text("Giỏ hàng trống.").foregroundColor(Theme.textFaint).frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .task { await loadDiaChi() }
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
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.divider))
        .padding(.horizontal)
    }

    private func itemRow(_ item: CartItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.tenSanPham) (\(item.tenBienThe))").font(.system(size: 15, weight: .semibold))
                if !item.toppings.isEmpty {
                    Text("+ " + item.toppings.map(\.ten).joined(separator: ", ")).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                }
                HStack(spacing: 10) {
                    Button { cart.setQuantity(item.id, soLuong: item.soLuong - 1) } label: { Image(systemName: "minus.circle") }
                    Text("\(item.soLuong)").fontWeight(.bold)
                    Button { cart.setQuantity(item.id, soLuong: item.soLuong + 1) } label: { Image(systemName: "plus.circle") }
                }
                .tint(Theme.primary)
            }
            Spacer()
            Text(formatTien(item.thanhTien)).font(.system(size: 14))
            Button { cart.removeItem(item.id) } label: { Image(systemName: "xmark").foregroundColor(Theme.danger) }
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
        let items = cart.items.map { DatMonItem(sanPhamBienTheId: $0.sanPhamBienTheId, soLuong: $0.soLuong, ghiChu: $0.ghiChu, toppingIds: $0.toppings.map(\.id)) }
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
