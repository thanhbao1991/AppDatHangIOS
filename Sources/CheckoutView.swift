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

    @State private var diaChi = ""
    /// Cảnh báo từ server khi voucher đã chọn KHÔNG áp dụng được (đơn vẫn tạo thành công, chỉ không
    /// giảm giá) — vd voucher hiện trong danh sách lúc CHƯA có đơn nên không kiểm được chính xác giỏ
    /// hàng (UpsizeMonMoi cần biết dòng hàng cụ thể). Phải xem xong mới điều hướng đi tiếp, tránh
    /// khách không biết vì sao không được giảm giá.
    @State private var voucherWarning: String?
    @State private var showLocationSettings = false
    @State private var showXacNhan = false
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
    /// Dòng địa chỉ đang chọn: id địa chỉ đã lưu / "custom" (nhập tay). dangSua = đang sửa chữ ngay trên dòng đó.
    @State private var chonKey = ""
    @State private var dangSua = false

    /// true = khách tự đặt ghim (kéo ghim hoặc bấm "Dùng vị trí hiện tại") cho địa chỉ đang chọn — chỉ
    /// khi đó backend mới cập nhật toạ độ của địa chỉ đã lưu. Đổi/chọn địa chỉ khác thì reset về false.
    @State private var ghimDoKhach = false

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

    private var xacNhanMessage: String {
        var lines = ["\(cart.totalCount) ly"]
        lines.append(nhanTaiQuan ? "Nhận tại quán" : "Giao đến: \(diaChi.trimmingCharacters(in: .whitespaces))")
        if !nhanTaiQuan { lines.append("Phí ship: " + (phiShip <= 0 ? "Miễn phí" : formatTien(phiShip))) }
        if soTienDungXu > 0 { lines.append("Dùng Xu: -" + formatTien(soTienDungXu)) }
        let httt = conLaiPhaiTra <= 0 ? "Đã thanh toán bằng Xu" : (hinhThucThanhToan == .codTraKhiNhanHang ? "Thanh toán khi nhận hàng" : "Chuyển khoản qua mã QR")
        lines.append("Thanh toán: \(httt)")
        lines.append("Cần trả: " + formatTien(conLaiPhaiTra))
        return lines.joined(separator: "\n")
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
                .alert("Xác nhận đặt hàng", isPresented: $showXacNhan) {
                    Button("Đặt hàng") { Task { await datHang() } }
                    Button("Kiểm tra lại", role: .cancel) {}
                } message: {
                    Text(xacNhanMessage)
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
            // Địa chỉ là bắt buộc (chọn địa chỉ đã lưu hoặc nhập tay) — vào trang tự chọn địa chỉ mặc
            // đã lưu nếu có; vị trí hiện tại chỉ dùng khi khách bấm nút.
            if !nhanTaiQuan {
                await tinhShip()
                await apDungDiaChiMacDinh()
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
        Text("🎁 Tặng 1 lượt quà Xu khi hoàn thành đơn")
            .font(.system(size: 13)).foregroundColor(Theme.textMuted)
    }

    private func diaChiRow(icon: String, text: String, chon: Bool, loading: Bool = false,
                            editing: Bool = false, coTheSua: Bool = false,
                            batDauSua: @escaping () -> Void = {}, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13))
            if editing {
                TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical)
                    .font(.system(size: 13))
                    .tint(Theme.primary)
                    .focused($diaChiFocused)
                    .onAppear { diaChiFocused = true }
                    .onSubmit { diaChiFocused = false }
                    .onChange(of: diaChi) { _ in
                        // Đang gõ → toạ độ cũ không còn khớp chữ, bỏ để geocode lại khi xong.
                        guard diaChiFocused else { return }
                        coord = nil
                        ghimDoKhach = false
                    }
            } else {
                Text(text).font(.system(size: 13)).lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if editing {
                Button { luuDiaChi() } label: {
                    Text("Lưu").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.primary).foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else if loading {
                ProgressView().scaleEffect(0.8)
            } else if chon && coTheSua && !editing {
                Button(action: batDauSua) {
                    Image(systemName: "pencil").font(.system(size: 14))
                        .padding(.horizontal, 6).padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
            } else if chon {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(chon ? Theme.primaryTint : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(chon ? Theme.primary : Theme.divider))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { if !editing { action() } }
        .foregroundColor(chon ? Theme.primary : Theme.textMuted)
    }

    /// Bấm Lưu: dùng cho đơn này + ghi vào sổ địa chỉ (sửa dòng đã lưu, hoặc thêm mới nếu là GPS/nhập tay).
    private func luuDiaChi() {
        let text = diaChi.trimmingCharacters(in: .whitespaces)
        dangSua = false
        diaChiFocused = false
        guard !text.isEmpty else { return }
        Task {
            await geocodeTypedAddressIfNeeded()
            if let cu = savedDiaChi.first(where: { $0.id == chonKey }) {
                _ = await APIClient.shared.suaDiaChi(cu.id, diaChi: text)
                await loadDiaChi()
                chonKey = cu.id
            } else {
                let r = await APIClient.shared.themDiaChi(text)
                await loadDiaChi()
                if r.success, let moi = savedDiaChi.first(where: { $0.diaChi == text }) { chonKey = moi.id }
            }
            diaChi = text
        }
    }

    private func ketThucSua() {
        guard dangSua else { return }
        dangSua = false
        Task { await geocodeTypedAddressIfNeeded() }
    }

    private var addressContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dangSua && !diaChiSuggestions.isEmpty {
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
                ForEach(savedDiaChi.sorted { $0.isDefault && !$1.isDefault }) { d in
                    let chon = chonKey == d.id
                    diaChiRow(icon: d.isDefault ? "star.fill" : "mappin",
                              text: chon ? diaChi : d.diaChi, chon: chon,
                              editing: dangSua && chon, coTheSua: true,
                              batDauSua: { dangSua = true }) {
                        Task { await chonDiaChiLuu(d) }
                    }
                }
                diaChiRow(icon: "square.and.pencil",
                          text: chonKey == "custom" && !diaChi.isEmpty ? diaChi : (savedDiaChi.isEmpty ? "Nhập địa chỉ" : "Nhập địa chỉ khác"),
                          chon: chonKey == "custom",
                          editing: dangSua && chonKey == "custom", coTheSua: true,
                          batDauSua: { dangSua = true }) {
                    chonKey = "custom"
                    coord = nil
                    ghimDoKhach = false
                    diaChi = ""; dangSua = true
                }
                Button {
                    Task { await dungViTriHienTai() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill").font(.system(size: 13))
                        Text("Dùng vị trí hiện tại của tôi").font(.system(size: 13, weight: .medium))
                        if locLoading { ProgressView().scaleEffect(0.8) }
                    }
                    .foregroundColor(Theme.primary)
                }
                .disabled(locLoading)
                .padding(.horizontal, 10).padding(.top, 4)
                if let coord {
                    DeliveryMapView(
                        shopCoordinate: CLLocationCoordinate2D(latitude: ship?.shopLat ?? 12.7095521, longitude: ship?.shopLong ?? 108.3016576),
                        deliveryCoordinate: coord,
                        routePoints: (ship?.tuyenDuong ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.long) },
                        onDragEnd: { newCoord in ghimDoKhach = true; Task { await applyCoord(newCoord) } }
                    )
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Kéo ghim để chọn đúng chỗ giao hàng")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 10)
                }
            }
            .onChange(of: diaChiFocused) { focused in
                if !focused { ketThucSua() }
            }

            if !locError.isEmpty { Text(locError).font(.system(size: 12)).foregroundColor(Theme.danger) }
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
                    }
                }
                Text("Đơn 2 ly hoặc hạng Bạc trở lên miễn phí ship")
                    .font(.system(size: 11)).foregroundColor(phiShip > 0 ? Theme.danger : Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Thanh dưới cùng: tổng tiền + nút Đặt hàng

    /// Chỉ chặn UI khi ĐÃ tải được giờ mở bán VÀ xác định là đóng cửa — chưa tải xong (gioMoBan ==
    /// nil, vd mất mạng) thì KHÔNG khoá nhầm, để server (DatMonAsync) là nơi chặn thật cuối cùng.
    private var dangDongCua: Bool { gioMoBan?.dangMoCua == false }

    /// Lý do nút Đặt hàng bị khoá — hiện ngay dưới nút để khách biết phải làm gì.
    private var lyDoKhongDatDuoc: String? {
        if dangDongCua, let gioMoBan {
            return "🕑 Quán đã đóng cửa. Giờ mở bán: \(gioMoBan.gioMoCua)h–\(gioMoBan.gioDongCua)h."
        }
        if !nhanTaiQuan && diaChi.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Vui lòng nhập hoặc chọn địa chỉ giao hàng để đặt hàng."
        }
        return nil
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundColor(Theme.danger) }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tổng cộng").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                    Text(formatTien(conLaiPhaiTra)).font(.system(size: 18, weight: .bold))
                }
                Spacer()
                Button {
                    showXacNhan = true
                } label: {
                    if loading { ProgressView().tint(.white) } else { Text("Đặt hàng").fontWeight(.bold) }
                }
                .buttonStyle(.gradientProminent)
                .frame(minWidth: 140)
                .disabled(loading || lyDoKhongDatDuoc != nil)
            }
            if let lyDo = lyDoKhongDatDuoc {
                Text(lyDo)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
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
        dangSua = false
        chonKey = d.id
        diaChi = d.diaChi
        ghimDoKhach = false
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
        if let known = await APIClient.shared.traToaDoDiaChi(trimmed) {
            await applyCoord(CLLocationCoordinate2D(latitude: known.lat, longitude: known.long))
            return
        }
        // Địa chỉ thường không ghi tỉnh — thêm vùng quán để Apple không geocode nhầm sang nơi khác.
        let coVung = trimmed.range(of: "đắk lắk", options: [.caseInsensitive, .diacriticInsensitive]) != nil
        let query = coVung ? trimmed : trimmed + ", Krông Pắc, Đắk Lắk"
        guard let found = await LocationHelper.shared.geocodeAddressString(query) else { return }
        // Apple hay đặt nhầm sang nơi khác — quá xa quán (Krông Pắc) thì bỏ, khách tự ghim trên bản đồ.
        let khoangCachKm = CLLocation(latitude: found.latitude, longitude: found.longitude)
            .distance(from: CLLocation(latitude: 12.7095521, longitude: 108.3016576)) / 1000
        guard khoangCachKm <= 10 else { return }
        await applyCoord(found)
    }

    /// Nút "Dùng vị trí hiện tại": đặt ghim tại GPS MỘT LẦN (không nhớ, không tự bật lại) — khách thấy ghim
    /// trên bản đồ và kéo chỉnh được. Chữ địa chỉ không đổi.
    private func dungViTriHienTai() async {
        locError = ""
        locLoading = true
        defer { locLoading = false }
        guard let location = await LocationHelper.shared.requestLocation() else {
            if LocationHelper.shared.isDenied {
                showLocationSettings = true
            } else {
                locError = "Không lấy được vị trí. Vui lòng thử lại."
            }
            return
        }
        ghimDoKhach = true
        await applyCoord(location.coordinate)
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
        let ghiChuTrimmed = cart.ghiChuDon.trimmingCharacters(in: .whitespaces)
        let ghiChuFull = ghiChuTrimmed.isEmpty ? ghiChuPrefix : "\(ghiChuPrefix) — \(ghiChuTrimmed)"
        let result = await APIClient.shared.datMon(
            items: items, diaChiText: nhanTaiQuan ? "" : diaChi.trimmingCharacters(in: .whitespaces), ghiChu: ghiChuFull,
            soDienThoaiText: nil, deliveryLat: nhanTaiQuan ? nil : coord?.latitude, deliveryLong: nhanTaiQuan ? nil : coord?.longitude, ghimDoKhachChinh: !nhanTaiQuan && ghimDoKhach,
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
