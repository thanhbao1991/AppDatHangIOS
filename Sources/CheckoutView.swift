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

    /// Bung/thu thanh địa chỉ gọn (kiểu Shopee) — mặc định thu gọn nếu đã có địa chỉ mặc định sẵn
    /// (khách quen), tự bung nếu chưa có gì để nhập (xem .task).
    @State private var diaChiExpanded = false

    /// Hình thức thanh toán khách chọn — KHÔNG có schema riêng ở backend, chỉ gắn tiền tố vào GhiChu
    /// cho nhân viên biết trước (xem datHang()). Mặc định COD nếu chưa từng đặt lần nào, còn lại nhớ
    /// đúng lựa chọn lần đặt gần nhất (Prefs.hinhThucThanhToan).
    @State private var hinhThucThanhToan: HinhThucThanhToan = HinhThucThanhToan(rawValue: Prefs.hinhThucThanhToan ?? "") ?? .codTraKhiNhanHang

    /// Ví Xu của khách — tải riêng (không dùng chung state SettingsView) chỉ để lấy soDu cho toggle
    /// "Dùng Xu". nil trong lúc chưa tải xong thì ẩn hẳn card Dùng Xu, tránh nhấp nháy "0đ" rồi đổi.
    @State private var vi: KhachHangVi?
    @State private var dungXu = false

    /// Voucher khách ĐANG đủ điều kiện dùng — tải lại mỗi lần vào trang (điều kiện có thể đổi ngay
    /// sau khi đặt đơn đầu tiên). Cùng 1 card với "Dùng Xu" theo yêu cầu, hiện phía trên.
    @State private var vouchers: [Voucher] = []
    /// SanPhamId khách ĐÃ TỪNG đặt (mọi kênh bán) — dùng để kiểm tra voucher MonMoiTraiNghiem
    /// (chiApDungKhiCoMonMoi), xem voucherDuDieuKien.
    @State private var sanPhamDaTungDat: [String] = []
    @State private var selectedVoucher: Voucher?
    /// Lựa chọn TẠM trong sheet "Chọn voucher" — chỉ ghi thật vào selectedVoucher khi bấm "Áp dụng",
    /// để bấm "Đóng"/vuốt xuống không làm mất lựa chọn đã áp dụng trước đó.
    @State private var pendingVoucher: Voucher?
    @State private var showVoucherSheet = false
    @State private var gioMoBan: GioMoBanDto?

    @State private var tenDuongs: [TenDuong] = []
    @FocusState private var diaChiFocused: Bool

    private var soDu: Double { vi?.soDu ?? 0 }
    private var tongTienHang: Double { cart.totalPrice }
    private var phiShip: Double { nhanTaiQuan ? 0 : (ship?.phiShip ?? 0) }
    /// Giảm giá voucher trừ THẲNG vào tiền hàng (trước ship) — không vượt quá tiền hàng.
    private var voucherGiam: Double { min(selectedVoucher?.soTienGiamThucTe(tongTienHang: tongTienHang, cartItems: cart.items) ?? 0, tongTienHang) }
    /// Voucher hợp lệ để hiện cho khách chọn — UpsizeMonMoi (chiApDungKhiCoSizeL) cần giỏ có ít nhất 1
    /// dòng Size L, ToppingMienPhi (chiApDungKhiCoTopping) cần giỏ có ít nhất 1 dòng topping,
    /// MonMoiTraiNghiem (chiApDungKhiCoMonMoi) cần giỏ có ít nhất 1 dòng sản phẩm khách CHƯA TỪNG đặt
    /// (đối chiếu sanPhamDaTungDat), DonToiThieu/DonToiThieuBac (donToiThieu) cần tổng tiền hàng đạt
    /// ngưỡng, SoLuongToiThieu (soLuongToiThieu) cần đủ số ly — nếu không đủ điều kiện thì mờ đi thay
    /// vì hiện rồi báo lỗi/-0đ. Server tự loại voucher đã dùng hết lượt (1 lần/tài khoản) khỏi
    /// getVoucherKhaDung() nên không cần kiểm lại ở đây.
    private var vouchersHienThi: [Voucher] {
        vouchers.filter { voucherDuDieuKien($0) }
    }

    /// true nếu giỏ hàng hiện tại thoả điều kiện phụ của voucher — voucher không có điều kiện phụ nào
    /// (hoặc điều kiện không thể kiểm tra được từ giỏ hàng, vd LenHang phụ thuộc chi tiêu cả tháng)
    /// luôn trả true, chấp nhận rủi ro chọn nhầm thấp vì server vẫn chặn thật lúc tạo đơn.
    private func voucherDuDieuKien(_ v: Voucher) -> Bool {
        if v.chiApDungKhiCoSizeL {
            return cart.items.contains { isSizeLBienThe($0.tenBienThe) }
        }
        if v.chiApDungKhiCoTopping {
            return cart.items.contains { !$0.toppings.isEmpty }
        }
        if v.chiApDungKhiCoMonMoi {
            return cart.items.contains { item in
                guard let sanPhamId = item.sanPhamId else { return false }
                return !sanPhamDaTungDat.contains(sanPhamId)
            }
        }
        if let donToiThieu = v.donToiThieu, donToiThieu > 0, tongTienHang < donToiThieu {
            return false
        }
        if let soLuongToiThieu = v.soLuongToiThieu, soLuongToiThieu > 0 {
            let tongSoLuong = cart.items.reduce(0) { $0 + $1.soLuong }
            return tongSoLuong >= soLuongToiThieu
        }
        return true
    }
    private var tongCanTra: Double { tongTienHang - voucherGiam + phiShip }
    private var soTienDungXu: Double { dungXu ? min(soDu, tongCanTra) : 0 }
    private var conLaiPhaiTra: Double { tongCanTra - soTienDungXu }
    /// Xu trả đủ 100% đơn — ẩn hẳn card Hình thức thanh toán (không còn gì phải chọn COD/QR nữa) và
    /// điều hướng sau khi đặt giống COD (không có QR để quét vì không còn tiền phải chuyển khoản).
    private var xuTraDu: Bool { dungXu && tongCanTra > 0 && soTienDungXu >= tongCanTra }

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                cardRow(topExtra: 6) { diaChiSection }
                cardRow { cardBox { donHangCardContent } }
                if soDu > 0 || !vouchersHienThi.isEmpty {
                    cardRow { cardBox { uuDaiCardContent } }
                }
                if !xuTraDu {
                    cardRow { cardBox { thanhToanCardContent } }
                }
                cardRow { cardBox { chiTietThanhToanCardContent } }
                cardRow { cardBox { ghiChuCardContent } }
            }
            .cardListBackground()
            bottomBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showVoucherSheet) { voucherSheet }
        .onChange(of: cart.items) { _ in
            if let selectedVoucher, !vouchersHienThi.contains(where: { $0.id == selectedVoucher.id }) {
                self.selectedVoucher = nil
            }
        }
        .alert("Lưu ý về voucher", isPresented: Binding(get: { voucherWarning != nil }, set: { if !$0 { voucherWarning = nil } })) {
            Button("Đã hiểu") {
                voucherWarning = nil
                pendingNavigationAfterOrder?()
                pendingNavigationAfterOrder = nil
            }
        } message: {
            Text(voucherWarning ?? "")
        }
        .task {
            async let viTask: KhachHangVi? = APIClient.shared.getVi()
            async let voucherTask: [Voucher] = APIClient.shared.getVoucherKhaDung()
            async let gioMoBanTask: GioMoBanDto? = APIClient.shared.getGioMoBan()
            async let sanPhamDaTungDatTask: [String] = APIClient.shared.getSanPhamDaTungDat()
            await loadDiaChi()
            await loadTenDuong()
            vi = await viTask
            vouchers = await voucherTask
            gioMoBan = await gioMoBanTask
            sanPhamDaTungDat = await sanPhamDaTungDatTask
            diaChiExpanded = diaChi.trimmingCharacters(in: .whitespaces).isEmpty
            // Xin định vị NGAY khi vào trang này (đúng lúc cần, khác bản cũ chỉ xin lúc khách tự bấm
            // nút GPS) — bỏ qua nếu đã có toạ độ rồi (địa chỉ mặc định đã kèm sẵn lat/long từ
            // loadDiaChi(), hoặc chọn "Nhận tại quán" không cần).
            if !nhanTaiQuan && coord == nil {
                await dungViTriHienTai()
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
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(Color.white)
        .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Thanh địa chỉ gọn (bung ra sửa) — gộp toggle Giao tận nơi/Nhận tại quán

    private var diaChiSection: some View {
        VStack(spacing: 0) {
            diaChiCompactBar
            if diaChiExpanded {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $nhanTaiQuan) {
                        Text("Giao tận nơi").tag(false)
                        Text("Nhận tại quán").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if nhanTaiQuan { pickupContent } else { addressContent }
                }
                .padding(14)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var diaChiCompactBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { diaChiExpanded.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill").foregroundColor(Theme.primary).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(nhanTaiQuan ? "Nhận tại quán" : "Giao tận nơi")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                    Text(nhanTaiQuan ? "Ghé quán lấy hàng, không mất phí ship" : (diaChi.isEmpty ? "Chưa có địa chỉ giao hàng" : diaChi))
                        .font(.system(size: 13)).foregroundColor(Theme.textMuted).lineLimit(1)
                }
                Spacer()
                Image(systemName: diaChiExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Chọn "Nhận tại quán": không cần địa chỉ/GPS/phí ship — KHÔNG mở quà Xu ngay ở đây nữa (trước
    /// đây bấm mở luôn lúc đặt, nay chỉ báo trước để khách biết, quà thật sự mở sau khi đơn hoàn
    /// thành — tránh khách "ăn quà" xong huỷ đơn/không tới lấy).
    private var pickupContent: some View {
        Text("🎁 Bạn sẽ được mở 1 lượt quà Xu sau khi đơn hoàn thành")
            .font(.system(size: 13)).foregroundColor(Theme.textMuted)
    }

    private var addressContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .tint(Theme.primary)
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

            // Nút "Dùng vị trí hiện tại" đã bỏ — từ khi có auto-xin định vị ngay lúc vào trang này
            // (.task ở body), bấm tay lại thành thừa. locLoading vẫn còn dùng cho spinner lúc auto-xin
            // chạy lần đầu.
            if locLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Đang lấy vị trí...").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            }
            if !locError.isEmpty { Text(locError).font(.system(size: 12)).foregroundColor(Theme.danger) }

            if estimatingShip {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Đang tính phí ship...").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            } else if let coord, let ship, let km = ship.khoangCachKm {
                DeliveryMapView(
                    shopCoordinate: CLLocationCoordinate2D(latitude: ship.shopLat, longitude: ship.shopLong),
                    deliveryCoordinate: coord,
                    routePoints: (ship.tuyenDuong ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.long) },
                    onDragEnd: { newCoord in Task { await applyCoord(newCoord) } }
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Khoảng cách ~\(String(format: "%.1f", km))km")
                    .font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onChange(of: cart.totalPrice) { _ in
            if let coord { Task { await applyCoord(coord) } }
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

    // MARK: - Card: Voucher (trên) + Dùng Xu (dưới) — chung 1 card theo yêu cầu, khớp bố cục Shopee.

    private var uuDaiCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !vouchersHienThi.isEmpty {
                Button {
                    pendingVoucher = selectedVoucher
                    showVoucherSheet = true
                } label: {
                    HStack {
                        Image(systemName: "ticket.fill").foregroundColor(Theme.primary).frame(width: 24)
                        if let selectedVoucher {
                            Text(selectedVoucher.ten).foregroundColor(.primary)
                        } else {
                            Text("Chọn voucher").foregroundColor(.primary)
                        }
                        Spacer()
                        if let selectedVoucher {
                            Text("-\(formatTien(selectedVoucher.soTienGiamThucTe(tongTienHang: tongTienHang, cartItems: cart.items)))").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.danger)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if soDu > 0 { Divider() }
            }
            if soDu > 0 {
                Toggle(isOn: $dungXu) {
                    HStack(spacing: 8) {
                        Text("🟡").font(.system(size: 16))
                        Text("Dùng Xu (số dư \(formatTien(soDu)))").font(.system(size: 14)).foregroundColor(.primary)
                    }
                }
                .tint(Theme.primary)
                .padding(.vertical, vouchersHienThi.isEmpty ? 0 : 6)
            }
        }
    }

    private var voucherSheet: some View {
        NavigationStack {
            List {
                // Không còn dòng "Không dùng voucher" riêng — bấm lại voucher đang chọn để bỏ chọn,
                // rồi bấm "Áp dụng" ở dưới để xác nhận (áp dụng hoặc bỏ áp dụng).
                // Hiện TẤT CẢ voucher (kể cả chưa đủ điều kiện Size L/topping) — mờ đi thay vì ẩn hẳn
                // để khách biết có voucher đang chờ, tạo động lực thêm món vào giỏ cho đủ điều kiện.
                ForEach(vouchers) { v in
                    let duDieuKien = voucherDuDieuKien(v)
                    cardRow {
                        Button {
                            guard duDieuKien else { return }
                            pendingVoucher = (pendingVoucher?.id == v.id) ? nil : v
                        } label: {
                            // Hiện Y HỆT card ở tab Voucher (nhanGiam/nhanGiamToiDa) — không hiện số
                            // tiền quy đổi riêng cho đơn hiện tại nữa, tránh cùng 1 voucher trông như
                            // 2 voucher khác nhau giữa 2 màn.
                            VoucherTicketCard(
                                ten: v.ten, moTa: v.moTa, ma: v.ma,
                                nhanGiam: v.nhanGiamGia,
                                nhanGiamToiDa: v.nhanGiamToiDa,
                                donToiThieu: v.donToiThieu,
                                daChon: pendingVoucher?.id == v.id
                            )
                            .padding(.horizontal).padding(.vertical, 6)
                            .opacity(duDieuKien ? 1 : 0.4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!duDieuKien)
                    }
                }
            }
            .cardListBackground()
            .navigationTitle("Chọn voucher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { showVoucherSheet = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    selectedVoucher = pendingVoucher
                    showVoucherSheet = false
                } label: {
                    Text("Áp dụng")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                }
                .background(Color(.systemBackground).overlay(Divider(), alignment: .top))
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
                chiTietRow("Phí vận chuyển", formatTien(phiShip))
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
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
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

    /// Đặt hàng — hình thức thanh toán KHÔNG có field trạng thái riêng ở backend, chỉ gắn tiền tố vào
    /// GhiChu cho nhân viên biết trước, cộng thêm dungVi/hinhThucThanhToan để server tự trừ ví
    /// (best-effort) và biết PhuongThucThanhToanId nào khi ghi dòng trừ ví. Điều hướng sau khi đặt:
    /// Xu trả đủ hoặc chọn COD → về thẳng tab Đơn hàng; chọn QR (còn tiền phải chuyển khoản) → sang
    /// trang quét mã.
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
            dungVi: dungXu, hinhThucThanhToan: hinhThucThanhToan.rawValue, voucherId: selectedVoucher?.id
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
