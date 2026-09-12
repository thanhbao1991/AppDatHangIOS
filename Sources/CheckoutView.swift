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
    /// Dòng đang chờ catalog nạp xong để mở sheet sửa — xem openEdit().
    @State private var openingItemId: UUID?

    /// Gợi ý tên đường khi gõ địa chỉ — cùng danh sách TenDuong Desktop dùng cho TenDuongBox, xem
    /// diaChiSuggestions/streetFragment bên dưới.
    @State private var tenDuongs: [TenDuong] = []
    @FocusState private var diaChiFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Giỏ hàng", icon: "🛒", centerTitle: true, trailing: notificationBell)

            ScrollView {
                if !cart.items.isEmpty {
                    // ScrollView + VStack thay vì List — từng thử dồn nhiều dòng món (ForEach động,
                    // mỗi dòng vài Button riêng: sửa/+/-/xoá) vào chung 1 "card" bên trong MỘT List
                    // row/Section duy nhất, gặp lỗi UITableView tái sử dụng cell sai (bấm sửa ra màn
                    // hình trắng, bấm số lượng xoá sạch giỏ hàng) — List không được thiết kế cho 1
                    // row chứa nhiều nhóm nút tương tác thay đổi số lượng động như vậy. Màn này
                    // không cần pull-to-refresh/swipe-action nên bỏ hẳn List, dùng ScrollView an toàn.
                    //
                    // Trình bày dạng timeline 3 bước (khoanh số + đường nối dọc) — khớp mẫu "Giới
                    // thiệu bạn bè" khách gửi, giúp phân biệt rõ luồng đặt hàng thay vì 3 card rời rạc
                    // trông ngang hàng nhau.
                    VStack(alignment: .leading, spacing: 0) {
                        stepCard(1, title: "Chi tiết hoá đơn", trailing: AnyView(qtyCountBadge)) { cartItemsBox }
                        stepCard(2, title: "Giao đến") { addressBox }
                        stepCard(3, title: "Thanh toán", isLast: true) { footerBox }
                    }
                    .padding(.top, 12)
                } else {
                    Text("Giỏ hàng trống.").foregroundColor(Theme.textFaint)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
                }
            }
            .background(Theme.bg)
        }
        .task {
            await loadDiaChi()
            await loadCatalog()
            await loadTenDuong()
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

    /// 1 bước trong timeline — khoanh số + đường nối dọc bên trái (đường nối co giãn theo chiều cao
    /// nội dung thật của bước đó nhờ HStack(alignment: .top) tự lấy chiều cao theo nhánh cao nhất,
    /// KHÔNG cần đo thủ công bằng GeometryReader), tiêu đề + nội dung bên phải.
    private func stepCard<Content: View>(_ number: Int, title: String, trailing: AnyView? = nil, isLast: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.primary))
                if !isLast {
                    Rectangle().fill(Theme.divider).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                    Spacer()
                    if let trailing { trailing }
                }
                content()
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
        .padding(.horizontal)
    }

    /// Style khối trắng bo góc bên trong 1 bước — như cardBoxStyle() nhưng KHÔNG có padding.horizontal
    /// riêng (stepCard đã tự canh lề ngang cho cả bước rồi, cộng thêm sẽ bị thụt lề đôi).
    private func stepBoxStyle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
    }

    private var qtyCountBadge: some View {
        Text("\(cart.totalCount) ly")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Theme.primary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.primaryTint)
            .clipShape(Capsule())
    }

    /// Bước 1: chi tiết hoá đơn — style khớp itemRow bên HoaDonDetailView (AppQuanLyIOS): thumbnail
    /// + số lượng dạng khoanh tròn, topping tô màu primary, ghi chú in nghiêng màu warning. Bấm vào
    /// dòng (trừ nút xoá) mở ProductPickerSheet ở chế độ sửa.
    private var cartItemsBox: some View {
        stepBoxStyle {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider() }
                    itemRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func itemThumbnail(_ hinhAnh: String?) -> some View {
        if let hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Theme.primaryTint).frame(width: 36, height: 36)
        }
    }

    private var addressBox: some View {
        stepBoxStyle {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($diaChiFocused)

            // Gợi ý tên đường (khớp fragment sau số nhà) — giống TenDuongBox bên TraSuaApp.Desktop,
            // chỉ hiện khi đang gõ trong ô này và chưa khớp chính xác 1 tên đường.
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
        }
    }

    /// Bước cuối: ghi chú + tạm tính + nút đặt hàng.
    private var footerBox: some View {
        stepBoxStyle {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Ghi chú", text: $ghiChu)
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
        }
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

    /// CheckoutView bị tạo lại mỗi lần chuyển qua tab Giỏ hàng (MainTabView dùng switch chứ không
    /// phải TabView giữ sống các tab — xem MainTabView.body), nên `sanPhams` luôn rỗng lúc mới vào
    /// tab và .task nạp lại từ đầu. Nếu khách bấm sửa món NGAY lúc đó (trước khi catalog kịp về),
    /// sanPham(for:) trả nil và sheet hiện trắng trơn — đợi nạp xong rồi mới quyết định mở sheet
    /// thay vì chỉ kiểm tra 1 lần lúc bấm.
    private func openEdit(_ item: CartItem) {
        guard openingItemId == nil else { return }
        Task {
            if sanPhams.isEmpty {
                openingItemId = item.id
                await loadCatalog()
                openingItemId = nil
            }
            if sanPham(for: item) != nil { editingItem = item }
        }
    }

    /// Dòng xoá nằm CÙNG dòng với tên sản phẩm (không phải cạnh giá) — Button xoá là SIBLING của
    /// Text tên, không nằm trong Button mở sửa, để tránh lồng Button-trong-Button (không đáng tin
    /// cậy trong SwiftUI, xem bài học ở lịch sử sửa file này). Phần còn lại (thumbnail/topping/ghi
    /// chú/giá) dùng .onTapGesture để mở sửa — Button xoá vẫn nhận tap của riêng nó trước vì nằm
    /// trong 1 view con có gesture recognizer riêng, ưu tiên hơn onTapGesture của view cha.
    private func itemRow(_ item: CartItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            itemThumbnail(item.hinhAnh)
            Text("\(item.soLuong)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.primary))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text("\(item.tenSanPham) (\(item.tenBienThe))").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Spacer()
                    Button { cart.removeItem(item.id) } label: { Image(systemName: "xmark").foregroundColor(Theme.danger) }
                }
                if !item.toppings.isEmpty {
                    Text(item.toppings.map { $0.soLuong > 1 ? "\($0.ten) x\($0.soLuong)" : $0.ten }.joined(separator: ", "))
                        .font(.system(size: 12)).foregroundColor(Theme.primary)
                }
                if let itemGhiChu = item.ghiChu, !itemGhiChu.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(itemGhiChu).font(.system(size: 12)).italic().foregroundColor(Theme.warning)
                }
                if openingItemId == item.id {
                    ProgressView().scaleEffect(0.7)
                }
                HStack {
                    Spacer()
                    Text(formatTien(item.thanhTien)).font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openEdit(item) }
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

    /// Gợi ý hiện khi đang gõ (còn focus) VÀ fragment sau số nhà chưa khớp CHÍNH XÁC 1 tên đường có
    /// sẵn — tránh hiện lại dropdown thừa ngay sau khi vừa chọn 1 gợi ý hoặc gõ đủ tên.
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
