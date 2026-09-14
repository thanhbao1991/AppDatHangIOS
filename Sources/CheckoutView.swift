import SwiftUI
import CoreLocation

/// Bước 2 = trang "Thanh toán" (địa chỉ + hình thức thanh toán) sau khi khách bấm "Đặt hàng" ở tab
/// Giỏ hàng (GioHangView) — tách khỏi tab Giỏ hàng theo bố cục Shopee: card Địa chỉ (gộp cả chọn
/// Giao tận nơi/Nhận tại quán), card Hình thức thanh toán, ghi chú + tổng tiền + nút Đặt hàng cố
/// định dưới cùng. KHÔNG còn timeline đánh số 1/2/3 (bản cũ gộp cả bước Hoá đơn vào đây) vì giờ mỗi
/// bước là 1 màn riêng, không cần đường nối giữa các card nữa.
struct CheckoutView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]
    @Binding var selectedTab: AppTab

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
    /// true trong lúc gọi API ước tính ship — RIÊNG với locLoading, vì applyCoord còn được gọi từ
    /// nhiều chỗ khác (chọn địa chỉ đã lưu, kéo ghim bản đồ, đổi giỏ hàng, tự xin định vị lúc vào
    /// trang) cũng cần feedback đang tải.
    @State private var estimatingShip = false
    /// Địa chỉ khách tự gõ tay trước đây KHÔNG có toạ độ nên bị tính ship = miễn phí bất kể xa gần —
    /// geocode thử khi rời focus ô nhập, xem geocodeTypedAddressIfNeeded().
    @State private var geocodingTyped = false

    /// true = "Nhận tại quán" (bỏ qua địa chỉ/GPS/phí ship), false = "Giao tận nơi" (mặc định).
    @State private var nhanTaiQuan = false
    @State private var dangQuay = false
    @State private var ketQuaQuay: String?

    /// Hình thức thanh toán khách chọn — chỉ ảnh hưởng bước SAU khi đặt xong (có hiện trang QR hay
    /// không) + ghi vào ghi chú cho nhân viên biết trước, KHÔNG có schema riêng ở backend (xem
    /// datHang() — tiền tố gắn thẳng vào GhiChu, giữ tối giản vì thu tiền COD vốn đã qua quy trình
    /// "thu tiền mặt" sẵn có của nhân viên/shipper, không cần trường trạng thái mới). Mặc định COD
    /// nếu chưa từng đặt lần nào, còn lại nhớ đúng lựa chọn lần đặt gần nhất (Prefs.hinhThucThanhToan)
    /// để lần sau tự chọn sẵn — xem paymentOptionRow() nơi lưu lại mỗi lần khách đổi.
    @State private var hinhThucThanhToan: HinhThucThanhToan = HinhThucThanhToan(rawValue: Prefs.hinhThucThanhToan ?? "") ?? .codTraKhiNhanHang

    @State private var tenDuongs: [TenDuong] = []
    @FocusState private var diaChiFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            List {
                cardRow(topExtra: 6) { cardBox { diaChiCardContent } }
                cardRow { cardBox { thanhToanCardContent } }
                cardRow { cardBox { ghiChuCardContent } }
            }
            .cardListBackground()
            bottomBar
        }
        .navigationTitle("Thanh toán")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDiaChi()
            await loadTenDuong()
            // Xin định vị NGAY khi vào trang này (đúng lúc cần, khác bản cũ chỉ xin lúc khách tự bấm
            // nút GPS) — bỏ qua nếu đã có toạ độ rồi (địa chỉ mặc định đã kèm sẵn lat/long từ
            // loadDiaChi(), hoặc chọn "Nhận tại quán" không cần).
            if !nhanTaiQuan && coord == nil {
                await dungViTriHienTai()
            }
        }
    }

    // MARK: - Card 1: Địa chỉ (gộp toggle Giao tận nơi/Nhận tại quán)

    private var diaChiCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Địa chỉ").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
            Picker("", selection: $nhanTaiQuan) {
                Text("Giao tận nơi").tag(false)
                Text("Nhận tại quán").tag(true)
            }
            .pickerStyle(.segmented)

            if nhanTaiQuan { pickupContent } else { addressContent }
        }
    }

    /// Chọn "Nhận tại quán": không cần địa chỉ/GPS/phí ship — kèm nút mở quà tặng Xu (dùng lại nguyên
    /// vòng quay may mắn hiện có bên UuDaiView, 1 lượt/ngày) để khuyến khích khách tự đến lấy.
    private var pickupContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ghé quán lấy hàng — không mất phí ship!").font(.system(size: 13)).foregroundColor(Theme.textMuted)

            if let ketQuaQuay {
                Text("🎉 " + ketQuaQuay)
                    .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button {
                    Task { await moQuaXu() }
                } label: {
                    HStack {
                        Spacer()
                        if dangQuay { ProgressView().tint(.white) } else { Text("🎁 Mở quà nhận Xu").fontWeight(.bold) }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .disabled(dangQuay)
            }
        }
    }

    private var addressContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($diaChiFocused)
                .onSubmit { Task { await geocodeTypedAddressIfNeeded() } }
                .onChange(of: diaChiFocused) { focused in
                    if !focused { Task { await geocodeTypedAddressIfNeeded() } }
                }

            if !diaChiSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(diaChiSuggestions, id: \.self) { ten in
                        Button { selectTenDuong(ten) } label: {
                            Text(ten)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        if ten != diaChiSuggestions.last { Divider() }
                    }
                }
                .background(Theme.primaryTint.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

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

            if estimatingShip {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Đang tính phí ship...").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            } else if let coord, let ship {
                if let km = ship.khoangCachKm {
                    DeliveryMapView(
                        shopCoordinate: CLLocationCoordinate2D(latitude: ship.shopLat, longitude: ship.shopLong),
                        deliveryCoordinate: coord,
                        routePoints: (ship.tuyenDuong ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.long) },
                        onDragEnd: { newCoord in Task { await applyCoord(newCoord) } }
                    )
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        Text("Khoảng cách ~\(String(format: "%.1f", km))km").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                        Spacer()
                        if ship.phiShip > 0 {
                            Text("Phí ship: \(formatTien(ship.phiShip))").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
                        } else {
                            freeShipBadge(size: 13)
                        }
                    }
                } else {
                    freeShipBadge()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if ship.phiShip > 0 {
                    let conThieu = ship.donGiaMienPhi - cart.totalPrice
                    if conThieu > 0 && conThieu <= 50_000 {
                        Text("Thêm \(formatTien(conThieu)) nữa để được miễn phí ship 🎁")
                            .font(.system(size: 12)).foregroundColor(Theme.primary)
                    }
                }
            }
        }
        .onChange(of: cart.totalPrice) { _ in
            if let coord { Task { await applyCoord(coord) } }
        }
    }

    private func freeShipBadge(size: CGFloat = 14) -> some View {
        Text("🎉 Miễn phí giao hàng").font(.system(size: size, weight: .bold)).foregroundColor(Theme.success)
    }

    // MARK: - Card 2: Hình thức thanh toán

    private var thanhToanCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hình thức thanh toán").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
            paymentOptionRow(.codTraKhiNhanHang, icon: "banknote", label: "Thanh toán khi nhận hàng")
            Divider()
            paymentOptionRow(.chuyenKhoanQR, icon: "qrcode", label: "Chuyển khoản qua mã QR")
        }
    }

    private func paymentOptionRow(_ method: HinhThucThanhToan, icon: String, label: String) -> some View {
        Button {
            hinhThucThanhToan = method
            Prefs.hinhThucThanhToan = method.rawValue
        } label: {
            HStack {
                Image(systemName: icon).foregroundColor(Theme.primary).frame(width: 24)
                Text(label).foregroundColor(.primary)
                Spacer()
                Image(systemName: hinhThucThanhToan == method ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(hinhThucThanhToan == method ? Theme.primary : Theme.divider)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card 3: Ghi chú

    private var ghiChuCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ghi chú").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
            TextField("Ghi chú cho quán (không bắt buộc)", text: $ghiChu)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Thanh dưới cùng: tổng tiền + nút Đặt hàng

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundColor(Theme.danger) }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tổng cộng").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                    Text(formatTien(cart.totalPrice + (ship?.phiShip ?? 0))).font(.system(size: 18, weight: .bold))
                }
                Spacer()
                Button {
                    Task { await datHang() }
                } label: {
                    if loading { ProgressView().tint(.white) } else { Text("Đặt hàng").fontWeight(.bold) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .frame(minWidth: 140)
                .disabled(loading || (!nhanTaiQuan && diaChi.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(Color.white)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .top)
    }

    // MARK: - Data loading / logic (giữ nguyên từ bản gộp cũ)

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

    private func loadTenDuong() async {
        tenDuongs = await APIClient.shared.getTenDuongList()
    }

    /// Khớp TenDuongBox bên Desktop: số nhà + ký tự phụ (vd "12A", "12/3B") + dấu ngăn cách phía sau
    /// — phần CÒN LẠI sau prefix này mới là fragment để so khớp/thay thế tên đường.
    private static let houseNumberPrefixRegex = try! NSRegularExpression(pattern: "^\\d+[A-Za-z]{0,2}(/\\d+[A-Za-z]{0,2})?[\\s.,-]*")

    private static func houseNumberPrefixRange(in text: String) -> Range<String.Index>? {
        let range = NSRange(text.startIndex..., in: text)
        guard let m = houseNumberPrefixRegex.firstMatch(in: text, range: range) else { return nil }
        return Range(m.range, in: text)
    }

    private func streetFragment(_ text: String) -> String {
        guard let r = Self.houseNumberPrefixRange(in: text) else { return text }
        return String(text[r.upperBound...])
    }

    private func housePrefix(_ text: String) -> String {
        guard let r = Self.houseNumberPrefixRange(in: text) else { return "" }
        return String(text[..<r.upperBound])
    }

    private var diaChiSuggestions: [String] {
        guard diaChiFocused else { return [] }
        let fragment = streetFragment(diaChi).trimmingCharacters(in: .whitespaces)
        guard !fragment.isEmpty else { return [] }
        let norm = normalizeVN(fragment)
        let matches = tenDuongs.map(\.ten).filter { normalizeVN($0).contains(norm) }
        if matches.count == 1 && normalizeVN(matches[0]) == norm { return [] }
        return Array(matches.prefix(8))
    }

    private func selectTenDuong(_ ten: String) {
        diaChi = housePrefix(diaChi) + ten
    }

    private func applyCoord(_ c: CLLocationCoordinate2D) async {
        coord = c
        ship = nil
        locError = ""
        estimatingShip = true
        defer { estimatingShip = false }
        let result = await APIClient.shared.uocTinhShip(lat: c.latitude, long: c.longitude, tongTienDon: cart.totalPrice)
        if result.isSuccess {
            ship = result.data
        } else {
            locError = result.message ?? "Không tính được phí ship lúc này, vui lòng thử lại."
        }
    }

    private func geocodeTypedAddressIfNeeded() async {
        let trimmed = diaChi.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, coord == nil, !geocodingTyped else { return }
        geocodingTyped = true
        defer { geocodingTyped = false }
        guard let found = await LocationHelper.shared.geocodeAddressString(trimmed) else { return }
        await applyCoord(found)
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

    /// Đặt hàng — hình thức thanh toán KHÔNG có field riêng ở backend (xem @State hinhThucThanhToan),
    /// gắn tiền tố vào GhiChu để nhân viên biết trước khách định trả kiểu gì, rồi điều hướng khác
    /// nhau: chọn QR thì sang trang quét mã ngay (như hành vi cũ), chọn COD thì về thẳng tab Đơn hàng
    /// (tiền thu sau qua quy trình "thu tiền mặt" sẵn có, không cần khách xem QR).
    private func datHang() async {
        guard !cart.items.isEmpty, nhanTaiQuan || !diaChi.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Vui lòng nhập địa chỉ giao hàng."
            return
        }
        loading = true; error = ""
        defer { loading = false }
        if clientOrderId == nil { clientOrderId = UUID().uuidString }
        let items = cart.items.map { DatMonItem(sanPhamBienTheId: $0.sanPhamBienTheId, soLuong: $0.soLuong, ghiChu: $0.ghiChu, toppings: $0.toppings.map { DatMonToppingItem(toppingId: $0.id, soLuong: $0.soLuong) }) }
        let ghiChuPrefix = hinhThucThanhToan == .codTraKhiNhanHang ? "💵 Thanh toán khi nhận hàng" : "📱 Chuyển khoản QR"
        let ghiChuTrimmed = ghiChu.trimmingCharacters(in: .whitespaces)
        let ghiChuFull = ghiChuTrimmed.isEmpty ? ghiChuPrefix : "\(ghiChuPrefix) — \(ghiChuTrimmed)"
        let result = await APIClient.shared.datMon(
            items: items, diaChiText: nhanTaiQuan ? "" : diaChi.trimmingCharacters(in: .whitespaces), ghiChu: ghiChuFull,
            soDienThoaiText: nil, deliveryLat: nhanTaiQuan ? nil : coord?.latitude, deliveryLong: nhanTaiQuan ? nil : coord?.longitude,
            clientOrderId: clientOrderId, nhanTaiQuan: nhanTaiQuan
        )
        if result.isSuccess, let data = result.data {
            clientOrderId = nil
            cart.clear()
            if hinhThucThanhToan == .chuyenKhoanQR {
                path.append(.thanhToan(hoaDonId: data.id))
            } else {
                selectedTab = .donHang
                path = []
            }
        } else {
            error = result.message ?? "Đặt hàng thất bại."
        }
    }

    /// Mở quà tặng Xu khi khách chọn "Nhận tại quán" — dùng lại NGUYÊN vòng quay may mắn hiện có
    /// (1 lượt/ngày, xem UuDaiView.quay()).
    private func moQuaXu() async {
        dangQuay = true
        defer { dangQuay = false }
        let res = await APIClient.shared.quayVongQuay()
        if res.isSuccess, let data = res.data {
            ketQuaQuay = data.label
        } else {
            ketQuaQuay = res.message ?? "Bạn đã dùng hết lượt quay hôm nay."
        }
    }
}

enum HinhThucThanhToan: String {
    case codTraKhiNhanHang = "COD"
    case chuyenKhoanQR = "QR"
}
