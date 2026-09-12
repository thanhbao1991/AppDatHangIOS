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

    /// true = "Nhận tại quán" (bỏ qua địa chỉ/GPS/phí ship), false = "Giao tận nơi" (mặc định, giữ
    /// hành vi cũ). Xem nhanHangBox — toggle nằm ở bước 2, đổi tên từ "Giao đến" thành "Nhận hàng".
    @State private var nhanTaiQuan = false
    @State private var dangQuay = false
    @State private var ketQuaQuay: String?

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

            // Quay lại dùng List theo yêu cầu. Bước 2/3 mỗi bước 1 row/Section riêng (qua cardRow).
            // Bước 1 (chi tiết hoá đơn) mỗi MÓN cũng là 1 row List thật riêng (ForEach trực tiếp,
            // không nhồi chung 1 row như bản trước từng nghi gây lỗi) — bắt buộc phải vậy để
            // .swipeActions hoạt động (chỉ áp dụng được trên row thật).
            List {
                if !cart.items.isEmpty {
                    // Bước 1 tách thành nhiều row THẬT (không nhồi chung 1 row như trước) để
                    // .swipeActions hoạt động trên từng món — đổi lại đường nối dọc chỉ còn kéo
                    // hết dòng tiêu đề (không xuyên hết danh sách món như 2 bước còn lại), đã xác
                    // nhận đánh đổi với khách trước khi làm.
                    cardRow(topExtra: 6) { stepHeaderRow(1, title: "Chi tiết hoá đơn", trailing: AnyView(qtyCountBadge)) }
                    ForEach(cart.items) { item in
                        let isFirst = item.id == cart.items.first?.id
                        let isLast = item.id == cart.items.last?.id
                        itemRow(item)
                            .padding(.horizontal, 12)
                            .padding(.top, isFirst ? 12 : 6)
                            .padding(.bottom, isLast ? 12 : 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardEdgeBackground(isFirst: isFirst, isLast: isLast))
                            // Lề ngoài áp bằng .padding SAU frame+background (KHÔNG dùng
                            // listRowInsets) — .swipeActions khiến List bỏ qua listRowInsets, render
                            // row edge-to-edge, đó là lý do card từng dính sát mép màn hình dù đã set
                            // insets 54/16. .padding ở đây co width của background lại đúng như lề
                            // thật, không phụ thuộc hành vi insets của row.
                            .padding(.leading, 54)
                            .padding(.trailing, 16)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { cart.removeItem(item.id) } label: {
                                    Label("Xoá", systemImage: "trash")
                                }
                            }
                    }
                    Color.clear.frame(height: 6)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    cardRow { stepCard(2, title: "Nhận hàng") { nhanHangBox } }
                    cardRow { stepCard(3, title: "Thanh toán", isLast: true) { footerBox } }
                } else {
                    Text("Giỏ hàng trống.").foregroundColor(Theme.textFaint)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
                        .listRowSeparator(.hidden)
                }
            }
            .cardListBackground()
        }
        .task {
            await loadDiaChi()
            await loadCatalog()
            await loadTenDuong()
        }
        .sheet(item: $editingItem) { item in
            // sanPham(for:) có thể trả nil (chưa nạp xong catalog, món đã đổi/ẩn khỏi menu, hoặc
            // không khớp được vì lý do khác) — dùng fallbackSanPham(for:) để sheet LUÔN mở được,
            // không bao giờ trắng trơn. Khi dùng fallback, chỉ đưa đúng các topping đã chọn sẵn vào
            // danh sách chọn (không biết đủ topping thật của món để hiện hết).
            let realSp = sanPham(for: item)
            let sp = realSp ?? fallbackSanPham(for: item)
            let toppingChoices = realSp != nil ? toppings : item.toppings.map { Topping(id: $0.id, ten: $0.ten, gia: $0.gia, ngungBan: false) }
            ProductPickerSheet(
                sanPham: sp,
                toppings: toppingChoices,
                isThuocLa: thuocLaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                khongChoKhongDa: khongChoKhongDaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                existing: item,
                onConfirm: { bienThe, soLuong, ghiChu, toppings in
                    cart.updateItem(item.id, sanPhamBienTheId: bienThe.id, tenBienThe: bienThe.tenBienThe, giaBan: bienThe.giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings)
                }
            ) { editingItem = nil }
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

    /// Chỉ phần tiêu đề của 1 bước (khoanh số + đường nối NGẮN + tên bước) — dùng khi nội dung bước
    /// đó cần tách thành nhiều row List thật riêng (vd bước 1 để .swipeActions hoạt động), khác
    /// stepCard ở chỗ không nhận content nên đường nối không giãn theo được, cố định ngắn.
    private func stepHeaderRow(_ number: Int, title: String, trailing: AnyView? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.primary))
                Rectangle().fill(Theme.divider).frame(width: 2, height: 16)
            }
            HStack {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                Spacer()
                if let trailing { trailing }
            }
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

    /// Nền + viền cho từng dòng món trong "Chi tiết hoá đơn" — ghép nhiều row List thật lại thành 1
    /// card trắng bo góc liền mạch (bo góc trên ở dòng đầu, bo góc dưới ở dòng cuối, viền trái/phải
    /// xuyên suốt, viền trên/dưới chỉ ở 2 đầu) để đồng bộ hình khối với box bước 2/3 (xem
    /// stepBoxStyle), dù buộc phải tách row thật để .swipeActions hoạt động trên từng món (xem
    /// comment ở body).
    private func cardEdgeBackground(isFirst: Bool, isLast: Bool) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? 12 : 0,
            bottomLeadingRadius: isLast ? 12 : 0,
            bottomTrailingRadius: isLast ? 12 : 0,
            topTrailingRadius: isFirst ? 12 : 0
        )
        return ZStack {
            Color.white
            VStack {
                if isFirst { Rectangle().fill(Theme.divider).frame(height: 1) }
                Spacer()
                if isLast { Rectangle().fill(Theme.divider).frame(height: 1) }
            }
            HStack {
                Rectangle().fill(Theme.divider).frame(width: 1)
                Spacer()
                Rectangle().fill(Theme.divider).frame(width: 1)
            }
        }
        .clipShape(shape)
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
    private func itemThumbnail(_ hinhAnh: String?) -> some View {
        if let hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Theme.primaryTint).frame(width: 36, height: 36)
        }
    }

    /// Bước 2: toggle "Giao tận nơi"/"Nhận tại quán" + nội dung tương ứng — 1 box duy nhất (khác
    /// addressContent/pickupContent bên dưới, KHÔNG tự bọc stepBoxStyle) để toggle và nội dung nằm
    /// chung 1 card, đổi mượt khi bấm chứ không nhảy 2 khối tách rời.
    private var nhanHangBox: some View {
        stepBoxStyle {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $nhanTaiQuan) {
                Text("Giao tận nơi").tag(false)
                Text("Nhận tại quán").tag(true)
            }
            .pickerStyle(.segmented)

            if nhanTaiQuan { pickupContent } else { addressContent }
        }
        }
    }

    /// Chọn "Nhận tại quán": không cần địa chỉ/GPS/phí ship — kèm nút mở quà tặng Xu (dùng lại nguyên
    /// vòng quay may mắn hiện có bên UuDaiView, 1 lượt/ngày) để khuyến khích khách tự đến lấy, đỡ tốn
    /// phí ship cho quán.
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
            .disabled(loading || (!nhanTaiQuan && diaChi.trimmingCharacters(in: .whitespaces).isEmpty))
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

    /// Dựng lại SanPham gốc chứa biến thể của 1 dòng trong giỏ — nil nếu món đã bị xoá/ẩn khỏi menu,
    /// hoặc catalog chưa nạp/nạp lỗi, hoặc không khớp được vì lý do khác. Có fallbackSanPham(for:)
    /// bên dưới để sheet sửa KHÔNG BAO GIỜ trắng trơn dù trường hợp này xảy ra.
    private func sanPham(for item: CartItem) -> SanPham? {
        sanPhams.first { $0.bienThe.contains { $0.id == item.sanPhamBienTheId } }
    }

    /// Dùng khi không dựng lại được SanPham thật từ catalog — tự tạo 1 SanPham "tối giản" chỉ có
    /// đúng biến thể đang có trong giỏ, đủ để sheet sửa mở ra sửa được số lượng/ghi chú/topping đã
    /// chọn (không đổi được sang size khác vì không biết các size khác). Đảm bảo bấm vào món LUÔN
    /// mở được sheet, không phụ thuộc catalog khớp đúng hay không.
    private func fallbackSanPham(for item: CartItem) -> SanPham {
        SanPham(
            id: item.sanPhamBienTheId, ten: item.tenSanPham, ngungBan: false, nhomSanPhamId: nil,
            hinhAnh: item.hinhAnh,
            bienThe: [SanPhamBienThe(id: item.sanPhamBienTheId, tenBienThe: item.tenBienThe, giaBan: item.giaBan, macDinh: true)],
            timKiem: nil, storeFoodId: nil, khongLenStore: false
        )
    }

    /// CheckoutView bị tạo lại mỗi lần chuyển qua tab Giỏ hàng (MainTabView dùng switch chứ không
    /// phải TabView giữ sống các tab — xem MainTabView.body), nên `sanPhams` luôn rỗng lúc mới vào
    /// tab và .task nạp lại từ đầu. Đợi catalog nạp xong (nếu chưa có) rồi mới mở sheet để ưu tiên
    /// dùng SanPham thật (đổi được size) khi có; luôn mở sheet dù catalog lỗi/không khớp, dùng
    /// fallbackSanPham(for:) — xem ProductPickerSheet ở .sheet(item:) bên trên.
    private func openEdit(_ item: CartItem) {
        guard openingItemId == nil else { return }
        if !sanPhams.isEmpty { editingItem = item; return }
        Task {
            openingItemId = item.id
            await loadCatalog()
            openingItemId = nil
            editingItem = item
        }
    }

    /// Xoá giờ qua vuốt trái (.swipeActions ở call site trong body, cần món là row List thật) thay
    /// vì nút X hiện sẵn trên dòng — đổi theo yêu cầu, khớp UX Shopee. Cả dòng dùng .onTapGesture để
    /// mở sửa (xem cách gắn ở body).
    private func itemRow(_ item: CartItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            itemThumbnail(item.hinhAnh)
            // Khớp style "Số lượng" bên ProductPickerSheet (màn thêm món) — chữ to đậm, không
            // khoanh tròn/nền, thay vì badge tròn trước đây.
            Text("\(item.soLuong)")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.tenSanPham) (\(item.tenBienThe))").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                if !item.toppings.isEmpty {
                    // Khớp cách hiện topping bên HoaDonDetailView (AppQuanLyIOS): kèm giá viết tắt
                    // ngay sau tên ("Trân châu +5k") thay vì chỉ hiện tên trơn không ai biết tốn
                    // thêm bao nhiêu.
                    Text(item.toppings.map { t in
                        let label = t.soLuong > 1 ? "\(t.ten) x\(t.soLuong)" : t.ten
                        return "\(label) +\(formatTienShort(t.gia * Double(t.soLuong)))"
                    }.joined(separator: ", "))
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
        locError = ""
        let result = await APIClient.shared.uocTinhShip(lat: c.latitude, long: c.longitude)
        if result.isSuccess {
            ship = result.data
        } else {
            // Không còn fallback đường chim bay phía server (xem DatHangService.UocTinhPhiShip) —
            // OSRM lỗi thì hiện lỗi thẳng ở đây thay vì âm thầm hiện phí ship sai/thiếu.
            locError = result.message ?? "Không tính được phí ship lúc này, vui lòng thử lại."
        }
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
        guard !cart.items.isEmpty, nhanTaiQuan || !diaChi.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Vui lòng nhập địa chỉ giao hàng."
            return
        }
        loading = true; error = ""
        defer { loading = false }
        if clientOrderId == nil { clientOrderId = UUID().uuidString }
        let items = cart.items.map { DatMonItem(sanPhamBienTheId: $0.sanPhamBienTheId, soLuong: $0.soLuong, ghiChu: $0.ghiChu, toppings: $0.toppings.map { DatMonToppingItem(toppingId: $0.id, soLuong: $0.soLuong) }) }
        let result = await APIClient.shared.datMon(
            items: items, diaChiText: nhanTaiQuan ? "" : diaChi.trimmingCharacters(in: .whitespaces), ghiChu: ghiChu.isEmpty ? nil : ghiChu,
            soDienThoaiText: nil, deliveryLat: nhanTaiQuan ? nil : coord?.latitude, deliveryLong: nhanTaiQuan ? nil : coord?.longitude,
            clientOrderId: clientOrderId, nhanTaiQuan: nhanTaiQuan
        )
        if result.isSuccess, let data = result.data {
            clientOrderId = nil
            cart.clear()
            path.append(.thanhToan(hoaDonId: data.id))
        } else {
            error = result.message ?? "Đặt hàng thất bại."
        }
    }

    /// Mở quà tặng Xu khi khách chọn "Nhận tại quán" — dùng lại NGUYÊN vòng quay may mắn hiện có
    /// (1 lượt/ngày, xem UuDaiView.quay()), không phải cơ chế thưởng riêng. Nếu khách đã quay hết
    /// lượt hôm nay (ở tab Ưu đãi hoặc lần "Nhận tại quán" trước), API trả lỗi — hiện thẳng message
    /// đó thay vì nút, không giả vờ còn lượt.
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
