import SwiftUI
import CoreLocation

/// Bước 2 = trang "Thanh toán" sau khi khách bấm "Đặt hàng" ở tab Giỏ hàng (GioHangView) — trình bày
/// theo bố cục Shopee: header tự vẽ (ẩn navbar hệ thống), thanh địa chỉ gọn có thể bung ra sửa, card
/// "Dùng Xu", card "Hình thức thanh toán" (ẩn nếu Xu trả đủ), card "Chi tiết thanh toán" (tổng tiền
/// hàng/phí ship/giảm giá Xu/tổng thanh toán), card Ghi chú, cuối cùng là thanh Tổng cộng + nút Đặt
/// hàng cố định dưới cùng.
struct CheckoutView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]
    @Binding var selectedTab: AppTab

    @State private var ghiChu = ""
    @State private var diaChi = ""
    /// Cảnh báo từ server khi voucher đã chọn KHÔNG áp dụng được (đơn vẫn tạo thành công, chỉ không
    /// giảm giá) — vd voucher hiện trong danh sách lúc CHƯA có đơn nên không kiểm được chính xác giỏ
    /// hàng (UpsizeMonMoi cần biết dòng hàng cụ thể). Phải xem xong mới điều hướng đi tiếp, tránh
    /// khách không biết vì sao không được giảm giá.
    @State private var voucherWarning: String?
    /// Icon "!" cạnh dòng "Phí vận chuyển" — nội dung giống hệt popup ở card Hạng thành viên
    /// (SettingsView.diemHangCard), đặt thêm ở đây vì đây mới là lúc khách thấy số tiền thật và
    /// thắc mắc tại sao (xem thảo luận 2026-10-01).
    @State private var showPhiShipInfo = false
    @State private var showLocationSettings = false
    @State private var pendingNavigationAfterOrder: (() -> Void)?
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

    /// true = đang dùng "Vị trí hiện tại" (chip đầu tiên, mặc định khi vào trang); false = địa chỉ đã lưu/tự chỉnh.
    @State private var usingGPS = false
    /// Bản đồ chỉ hiện khi dùng vị trí hiện tại (hoặc đã kéo ghim chỉnh tay) — địa chỉ đã lưu không cần.
    @State private var hienBanDo = false

    /// Hình thức thanh toán khách chọn — KHÔNG có schema riêng ở backend, chỉ gắn tiền tố vào GhiChu
    /// cho nhân viên biết trước (xem datHang()). Mặc định COD nếu chưa từng đặt lần nào, còn lại nhớ
    /// đúng lựa chọn lần đặt gần nhất (Prefs.hinhThucThanhToan).
    @State private var hinhThucThanhToan: HinhThucThanhToan = HinhThucThanhToan(rawValue: Prefs.hinhThucThanhToan ?? "") ?? .codTraKhiNhanHang

    @State private var gioMoBan: GioMoBanDto?

    @State private var tenDuongs: [TenDuong] = []
    @FocusState private var diaChiFocused: Bool

    // Voucher + Xu: 2026-09-27 chuyển lựa chọn hẳn LÊN CartStore, chọn NGAY tại tab Giỏ hàng (tham
    // khảo Long Châu) — trang Thanh toán KHÔNG còn cho sửa nữa, chỉ đọc lại state đó để tính tổng tiền
    // và hiện dòng tóm tắt "Giảm giá voucher"/"Dùng Xu" trong chiTietThanhToanCardContent (muốn đổi
    // voucher/Xu phải quay lại tab Giỏ hàng).
    private var soDu: Double { cart.soDuXu }
    private var tongTienHang: Double { cart.totalPrice }
    private var phiShip: Double { nhanTaiQuan ? 0 : (ship?.phiShip ?? 0) }
    private var voucherGiam: Double { cart.voucherGiam(tongTienHang: tongTienHang) }
    private var tongCanTra: Double { tongTienHang - voucherGiam + phiShip }

    /// Giải thích CỤ THỂ cho đơn đang đặt (khác bản chung chung ở card Hạng thành viên bên
    /// SettingsView — ở đây đã có đủ số ly + kết quả ước tính ship thật nên tính ra số km miễn phí
    /// của riêng đơn này thay vì nói chung chung, xem thảo luận 2026-10-01).
    private var phiShipInfoMessage: String {
        let soLy = cart.totalCount
        let hang = ship?.hangThangTruoc?.isEmpty == false ? ship!.hangThangTruoc! : KhachHangSession.shared.hang
        var msg = "Ship 5.000đ/đơn.\nFree ship nếu từ 2 ly hoặc hạng Bạc trở lên (tháng trước)."
        msg += "\n\nBạn: \(soLy) ly · hạng \(hang)"
        if phiShip == 0 { msg += "\n🎉 Đơn này FREE SHIP!" }
        return msg
    }

    /// Trần 50% (thêm 2026-09-23, chặn farm "đơn thành công +1 lượt quay" bằng Xu trả đủ 100%) đã BỎ
    /// theo yêu cầu 2026-09-27 — khớp DatHangService.DatMonAsync bên backend, Xu giờ trả được tối đa
    /// 100% đơn.
    private var soTienDungXu: Double { cart.dungXu ? min(soDu, tongCanTra) : 0 }
    private var conLaiPhaiTra: Double { tongCanTra - soTienDungXu }
    /// Xu trả đủ 100% đơn — ẩn hẳn card Hình thức thanh toán (không còn gì phải chọn COD/QR nữa) và
    /// điều hướng sau khi đặt giống COD (không có QR để quét vì không còn tiền phải chuyển khoản).
    private var xuTraDu: Bool { cart.dungXu && tongCanTra > 0 && soTienDungXu >= tongCanTra }

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                cardRow(topExtra: 6) { diaChiSection }
                if !xuTraDu {
                    cardRow { cardBox { thanhToanCardContent } }
                }
                cardRow { cardBox { donHangCardContent } }
                cardRow { cardBox { chiTietThanhToanCardContent } }
                cardRow { cardBox { ghiChuCardContent } }
            }
            .cardListBackground()
            bottomBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .popupHost { host in
            host
                .alert("Lưu ý về voucher", isPresented: Binding(get: { voucherWarning != nil }, set: { if !$0 { voucherWarning = nil } })) {
                    Button("Đã hiểu") {
                        voucherWarning = nil
                        pendingNavigationAfterOrder?()
                        pendingNavigationAfterOrder = nil
                    }
                } message: {
                    Text(voucherWarning ?? "")
                }
                .alert("🛵 Cách tính phí ship", isPresented: $showPhiShipInfo) {
                    Button("Đã hiểu") {}
                } message: {
                    Text(phiShipInfoMessage)
                }
                .alert("Chưa cho phép định vị", isPresented: $showLocationSettings) {
                    Button("Mở Cài đặt") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Button("Để sau", role: .cancel) {}
                } message: {
                    Text("Bạn đã từ chối quyền vị trí trước đó nên iOS không hỏi lại được. Vào Cài đặt > Đenn Coffee > Vị trí, chọn \"Khi dùng ứng dụng\" để dùng vị trí hiện tại.")
                }
        }
        .task {
            async let gioMoBanTask: GioMoBanDto? = APIClient.shared.getGioMoBan()
            await loadDiaChi()
            await loadTenDuong()
            // Voucher/Xu thường đã tải sẵn từ tab Giỏ hàng (loadUuDaiIfNeeded tự bỏ qua nếu tải rồi)
            // — chỉ thật sự gọi API ở đây khi khách vào thẳng trang này chưa từng ghé Giỏ hàng.
            await cart.loadUuDaiIfNeeded()
            gioMoBan = await gioMoBanTask
            // Mặc định chọn chip "Vị trí hiện tại" (kiểu Grab/ShopeeFood) — không lấy được GPS
            // (từ chối quyền/tín hiệu yếu) thì lùi về địa chỉ mặc định đã lưu.
            if !nhanTaiQuan {
                await tinhShip()
                let coGPS = await dungViTriHienTai()
                if !coGPS { await apDungDiaChiMacDinh() }
            }
        }
    }

    // MARK: - Header tự vẽ (thay navbar hệ thống — khớp bố cục Shopee: nền trắng, back bên trái, tiêu
    // đề giữa màu đen thay vì thanh xanh brand như các trang khác).

    private var header: some View {
        ZStack {
            Text("Thanh toán").font(.system(size: 17, weight: .bold)).foregroundColor(.primary)
            HStack {
                Button {
                    if !path.isEmpty { path.removeLast() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.primary)
                        .frame(width: 44, height: 44, alignment: .center)
                }
                Spacer()
            }
        }
        // Icon căn .center trong ô 44x44 (trước .leading khiến icon dính sát mép trái, cộng padding
        // ngang 4 quá mỏng — feedback 2026-09-27 "nút back lệch sát mép") + tăng padding ngang lên 8.
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color.white)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Thẻ địa chỉ — toggle Giao tận nơi/Nhận tại quán, luôn mở sẵn để khách thấy ghim bản đồ

    private var diaChiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $nhanTaiQuan) {
                Text("Giao tận nơi").tag(false)
                Text("Nhận tại quán").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: nhanTaiQuan) { nhan in
                if !nhan { Task { await tinhShip() } }
            }

            if nhanTaiQuan { pickupContent } else { addressContent }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// Chọn "Nhận tại quán": không cần địa chỉ/GPS/phí ship — KHÔNG mở quà Xu ngay ở đây nữa (trước
    /// đây bấm mở luôn lúc đặt, nay chỉ báo trước để khách biết, quà thật sự mở sau khi đơn hoàn
    /// thành — tránh khách "ăn quà" xong huỷ đơn/không tới lấy).
    private var pickupContent: some View {
        Text("🎁 Bạn sẽ được mở 1 lượt quà Xu sau khi đơn hoàn thành")
            .font(.system(size: 13)).foregroundColor(Theme.textMuted)
    }

    private func diaChiRow(icon: String, text: String, chon: Bool, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13))
                Text(text).font(.system(size: 13)).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if loading {
                    ProgressView().scaleEffect(0.8)
                } else if chon {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(chon ? Theme.primaryTint : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(chon ? Theme.primary : Theme.divider))
        }
        .buttonStyle(.plain)
        .foregroundColor(chon ? Theme.primary : Theme.textMuted)
    }

    private var addressContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .tint(Theme.primary)
                .opacity(locLoading ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.25), value: locLoading)
                .focused($diaChiFocused)
                .onSubmit { Task { await geocodeTypedAddressIfNeeded() } }
                .onChange(of: diaChiFocused) { focused in
                    if !focused { Task { await geocodeTypedAddressIfNeeded() } }
                }
                .onChange(of: diaChi) { _ in
                    // Khách đang gõ/sửa tay → toạ độ cũ không còn khớp với chữ, bỏ đi để geocode lại
                    // (nếu không, phí ship vẫn tính theo chỗ cũ).
                    guard diaChiFocused else { return }
                    coord = nil; usingGPS = false; hienBanDo = false
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

            VStack(spacing: 6) {
                diaChiRow(icon: "location.fill", text: locLoading ? "Đang lấy vị trí..." : "Vị trí hiện tại", chon: usingGPS, loading: locLoading) {
                    Task { await dungViTriHienTai(baoLoi: true) }
                }
                ForEach(savedDiaChi.sorted { $0.isDefault && !$1.isDefault }) { d in
                    diaChiRow(icon: d.isDefault ? "star.fill" : "mappin", text: d.diaChi, chon: !usingGPS && diaChi == d.diaChi) {
                        Task { await chonDiaChiLuu(d) }
                    }
                }
            }

            if !locError.isEmpty { Text(locError).font(.system(size: 12)).foregroundColor(Theme.danger) }

            if let coord, let ship {
                if hienBanDo {
                    DeliveryMapView(
                        shopCoordinate: CLLocationCoordinate2D(latitude: ship.shopLat, longitude: ship.shopLong),
                        deliveryCoordinate: coord,
                        routePoints: (ship.tuyenDuong ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.long) },
                        onDragEnd: { newCoord in usingGPS = false; Task { await applyCoord(newCoord) } }
                    )
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onChange(of: cart.totalCount) { _ in
            Task { await tinhShip() }
        }
    }

    // MARK: - Card: Chi tiết đơn hàng (xem lại, KHÔNG sửa được ở đây — icon khoá nhắc rõ, muốn sửa
    // món phải quay lại tab Giỏ hàng, tránh nhầm 2 nơi cùng sửa được 1 giỏ hàng).

    private var donHangCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Chi tiết đơn hàng").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                Spacer()
                Text("\(cart.totalCount) ly")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.primaryTint).clipShape(Capsule())
            }
            Divider()
            ForEach(Array(cart.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                HStack(alignment: .top, spacing: 8) {
                    Text("\(item.soLuong)x").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMuted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.tenSanPham)\(bienTheSuffix(item.tenBienThe))").font(.system(size: 14)).foregroundColor(.primary)
                        if !item.toppings.isEmpty {
                            Text(item.toppings.map { $0.soLuong > 1 ? "\($0.ten) x\($0.soLuong)" : $0.ten }.joined(separator: ", "))
                                .font(.system(size: 12)).foregroundColor(Theme.primary)
                        }
                        if let ghiChu = item.ghiChu, !ghiChu.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(ghiChu).font(.system(size: 12)).italic().foregroundColor(Theme.warning)
                        }
                    }
                    Spacer()
                    Text(formatTien(item.thanhTien)).font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Card: Hình thức thanh toán

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

    // MARK: - Card: Chi tiết thanh toán

    private var chiTietThanhToanCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chi tiết thanh toán").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
            chiTietRow("Tổng tiền hàng", formatTien(tongTienHang))
            if voucherGiam > 0 {
                chiTietRow("Giảm giá voucher", "-" + formatTien(voucherGiam), color: Theme.danger)
            }
            if !nhanTaiQuan {
                Button { showPhiShipInfo = true } label: {
                HStack {
                    Text("Phí vận chuyển").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    Spacer()
                    HStack(spacing: 6) {
                        // phiShipGoc = phí nếu KHÔNG có ưu đãi miễn phí ly/hạng — chỉ hiện gạch ngang
                        // khi thật sự có giảm (goc > thật), tránh gạch 1 số trùng chính nó.
                        if let goc = ship?.phiShipGoc, goc > phiShip {
                            Text(formatTien(goc)).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                                .strikethrough(color: Theme.textMuted)
                        }
                        if phiShip <= 0 {
                            Text("Miễn phí").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.success)
                        } else {
                            Text(formatTien(phiShip)).font(.system(size: 13)).foregroundColor(.primary)
                        }
                        Image(systemName: "info.circle").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    }
                }
                .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if soTienDungXu > 0 {
                chiTietRow("Dùng Xu", "-" + formatTien(soTienDungXu), color: Theme.danger)
            }
            Divider()
            chiTietRow("Tổng thanh toán", formatTien(conLaiPhaiTra), bold: true)
        }
    }

    private func chiTietRow(_ label: String, _ value: String, bold: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(bold ? .primary : Theme.textMuted)
            Spacer()
            Text(value).font(.system(size: bold ? 15 : 13, weight: bold ? .bold : .regular)).foregroundColor(color)
        }
    }

    // MARK: - Card: Ghi chú

    private var ghiChuCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ghi chú thêm").font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
            TextField("", text: $ghiChu)
                .textFieldStyle(.roundedBorder)
                .tint(Theme.primary)
        }
    }

    // MARK: - Thanh dưới cùng: tổng tiền + nút Đặt hàng

    /// Chỉ chặn UI khi ĐÃ tải được giờ mở bán VÀ xác định là đóng cửa — chưa tải xong (gioMoBan ==
    /// nil, vd mất mạng) thì KHÔNG khoá nhầm, để server (DatMonAsync) là nơi chặn thật cuối cùng.
    private var dangDongCua: Bool { gioMoBan?.dangMoCua == false }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if dangDongCua, let gioMoBan {
                Text("🕑 Quán đã đóng cửa. Giờ mở bán: \(gioMoBan.gioMoCua)h–\(gioMoBan.gioDongCua)h.")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.danger)
            }
            if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundColor(Theme.danger) }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tổng cộng").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                    Text(formatTien(conLaiPhaiTra)).font(.system(size: 18, weight: .bold))
                }
                Spacer()
                Button {
                    Task { await datHang() }
                } label: {
                    if loading { ProgressView().tint(.white) } else { Text("Đặt hàng").fontWeight(.bold) }
                }
                .buttonStyle(.gradientProminent)
                .frame(minWidth: 140)
                .disabled(loading || dangDongCua || (!nhanTaiQuan && diaChi.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(Color.white)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .top)
    }

    // MARK: - Data loading / logic

    private func loadDiaChi() async {
        savedDiaChi = await APIClient.shared.getDiaChiList()
    }

    private func apDungDiaChiMacDinh() async {
        guard let macDinh = savedDiaChi.first(where: \.isDefault) else { return }
        await chonDiaChiLuu(macDinh)
    }

    /// Địa chỉ đã lưu: có lat/long thì dùng; thiếu thì BỎ toạ độ cũ (tránh tính ship theo chỗ trước đó)
    /// rồi geocode từ chữ — không ra thì để trống, nút Đặt hàng bị khoá + báo khách chọn lại.
    private func chonDiaChiLuu(_ d: DiaChiKhachHang) async {
        usingGPS = false
        hienBanDo = false
        diaChi = d.diaChi
        if let lat = d.lat, let long = d.long {
            await applyCoord(CLLocationCoordinate2D(latitude: lat, longitude: long))
        } else {
            coord = nil
            await geocodeTypedAddressIfNeeded()
        }
    }


    private func loadTenDuong() async {
        tenDuongs = await APIClient.shared.getTenDuongList()
    }

    // Logic gợi ý tên đường (tách số nhà, so khớp fragment) dùng chung qua DiaChiSuggestion.swift —
    // SettingsView (Thêm/Sửa địa chỉ tab Tài khoản) cũng dùng lại đúng hàm này.
    private var diaChiSuggestions: [String] {
        guard diaChiFocused else { return [] }
        return DiaChiSuggestion.matches(for: diaChi, in: tenDuongs)
    }

    private func selectTenDuong(_ ten: String) {
        diaChi = DiaChiSuggestion.apply(ten, to: diaChi)
    }

    private func applyCoord(_ c: CLLocationCoordinate2D) async {
        coord = c
        locError = ""
        await tinhShip()
    }

    /// Phí ship cố định (xem backend ShippingFeeHelper) — toạ độ chỉ để shipper tìm đường, không ảnh hưởng phí.
    private func tinhShip() async {
        guard !nhanTaiQuan else { return }
        estimatingShip = true
        defer { estimatingShip = false }
        let result = await APIClient.shared.uocTinhShip(lat: coord?.latitude ?? 0, long: coord?.longitude ?? 0, tongTienDon: cart.totalPrice, soLuong: cart.totalCount)
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
        // Địa chỉ thường không ghi tỉnh — thêm vùng quán để Apple không geocode nhầm sang nơi khác.
        let coVung = trimmed.range(of: "đắk lắk", options: [.caseInsensitive, .diacriticInsensitive]) != nil
        let query = coVung ? trimmed : trimmed + ", Krông Pắc, Đắk Lắk"
        guard let found = await LocationHelper.shared.geocodeAddressString(query) else { return }
        await applyCoord(found)
    }

    /// true nếu lấy được GPS và đã áp dụng. Thất bại chỉ báo lỗi khi khách tự bấm chip — gọi tự động
    /// lúc vào trang thì caller lùi về địa chỉ mặc định, không hiện lỗi.
    @discardableResult
    private func dungViTriHienTai(baoLoi: Bool = false) async -> Bool {
        locError = ""
        locLoading = true
        defer { locLoading = false }
        guard let location = await LocationHelper.shared.requestLocation() else {
            if baoLoi {
                if LocationHelper.shared.isDenied {
                    showLocationSettings = true
                } else {
                    locError = "Không lấy được vị trí. Bạn có thể kéo ghim trên bản đồ hoặc chọn địa chỉ đã lưu."
                }
            }
            return false
        }
        usingGPS = true
        hienBanDo = true
        // Hiện ghim + chữ địa chỉ ngay, tính ship chạy song song (không chờ nhau).
        coord = location.coordinate
        locError = ""
        locLoading = false
        async let phi: Void = tinhShip()
        if let address = await LocationHelper.shared.reverseGeocode(location) {
            diaChi = address
        }
        await phi
        return true
    }

    /// Đặt hàng — hình thức thanh toán KHÔNG có field trạng thái riêng ở backend, chỉ gắn tiền tố vào
    /// GhiChu cho nhân viên biết trước, cộng thêm dungVi/hinhThucThanhToan để server tự trừ ví
    /// (best-effort) và biết PhuongThucThanhToanId nào khi ghi dòng trừ ví. Điều hướng sau khi đặt:
    /// Xu trả đủ hoặc chọn COD → về thẳng tab Đơn hàng; chọn QR (còn tiền phải chuyển khoản) → sang
    /// trang quét mã (ThanhToanView) NGAY — quay lại đổi 2026-09-28 sau khi thử bỏ hẳn bước này
    /// (feedback: "tôi nhầm, bấm thanh toán vẫn phải hiện mã QR"). Trang quét mã xong bấm "Xong" tự
    /// điều hướng về tab Đơn hàng qua onDone (xem MainTabView) — KHÔNG phải trang chi tiết đơn hàng.
    private func datHang() async {
        guard !cart.items.isEmpty, nhanTaiQuan || !diaChi.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Vui lòng nhập địa chỉ giao hàng."
            return
        }
        loading = true; error = ""
        defer { loading = false }
        if clientOrderId == nil { clientOrderId = UUID().uuidString }
        let items = cart.items.map { DatMonItem(sanPhamBienTheId: $0.sanPhamBienTheId, soLuong: $0.soLuong, ghiChu: $0.ghiChu, toppings: $0.toppings.map { DatMonToppingItem(toppingId: $0.id, soLuong: $0.soLuong) }) }
        let ghiChuPrefix = xuTraDu
            ? "🟡 Đã thanh toán bằng Xu"
            : (hinhThucThanhToan == .codTraKhiNhanHang ? "💵 Thanh toán khi nhận hàng" : "📱 Chuyển khoản QR")
        let ghiChuTrimmed = ghiChu.trimmingCharacters(in: .whitespaces)
        let ghiChuFull = ghiChuTrimmed.isEmpty ? ghiChuPrefix : "\(ghiChuPrefix) — \(ghiChuTrimmed)"
        let result = await APIClient.shared.datMon(
            items: items, diaChiText: nhanTaiQuan ? "" : diaChi.trimmingCharacters(in: .whitespaces), ghiChu: ghiChuFull,
            soDienThoaiText: nil, deliveryLat: nhanTaiQuan ? nil : coord?.latitude, deliveryLong: nhanTaiQuan ? nil : coord?.longitude,
            clientOrderId: clientOrderId, nhanTaiQuan: nhanTaiQuan,
            dungVi: cart.dungXu, hinhThucThanhToan: hinhThucThanhToan.rawValue, voucherId: cart.selectedVoucher?.id, laDatLai: cart.laDatLai
        )
        if result.isSuccess, let data = result.data {
            clientOrderId = nil
            cart.clear()
            let navigate: () -> Void = {
                if !xuTraDu && hinhThucThanhToan == .chuyenKhoanQR {
                    path.append(.thanhToan(hoaDonId: data.id))
                } else {
                    selectedTab = .donHang
                    path = []
                }
            }
            if let warnings = result.warnings, !warnings.isEmpty {
                pendingNavigationAfterOrder = navigate
                voucherWarning = warnings.joined(separator: "\n")
            } else {
                navigate()
            }
        } else {
            error = result.message ?? "Đặt hàng thất bại."
        }
    }
}

enum HinhThucThanhToan: String {
    case codTraKhiNhanHang = "COD"
    case chuyenKhoanQR = "QR"
}
