import SwiftUI

/// Port từ OrderDetailScreen.tsx — timeline trạng thái, danh sách món, tổng kết tiền, huỷ/đặt lại.
/// Đánh giá đơn đã chuyển hẳn sang DanhGiaSheet mở thẳng từ card OrderStatusView (feedback
/// 2026-09-28: "ko cần thiết phải vào chi tiết hoá đơn để đánh giá") — trang này không còn phần đó.
struct OrderDetailView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var donHangPath: [DonHangRoute]
    @Binding var selectedTab: AppTab
    @Binding var cartPath: [HomeRoute]
    @Environment(\.dismiss) private var dismiss

    @State var order: DonHangKhach

    @State private var dangHuy = false
    @State private var showHuyConfirm = false
    @State private var alertMessage: (title: String, message: String)?

    private let steps: [TrangThaiDon] = [.choXacNhan, .daXacNhan, .dangGiao, .hoanTat]
    private var currentStep: Int { steps.firstIndex(of: order.trangThai) ?? 0 }

    var body: some View {
        ScrollView {
            // Chuyển toàn trang sang FLAT (feedback 2026-09-28) — bỏ hẳn nền xám bo góc `card` cũ,
            // mỗi mục giờ chỉ còn padding dọc + Divider phân cách, khớp phong cách các màn đã đổi
            // flat khác trong app (OrderStatusView/GioHangView/LichSuViView).
            VStack(alignment: .leading, spacing: 0) {
                section {
                    // Bỏ hẳn mã hoá đơn khỏi đầu trang (feedback 2026-09-28) — vô nghĩa với khách,
                    // cùng lý do đã bỏ ở OrderStatusView/LichSuCongNoView, chỉ còn giữ ở
                    // confirmationDialog lúc huỷ đơn cho rõ đang thao tác đúng đơn nào.
                    Text(formatThongBaoTime(order.ngayGio)).font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    // Đơn huỷ không đi qua timeline 4 bước (steps.firstIndex trả nil, sẽ hiện sai
                    // thành "bước 0" như chưa huỷ gì) — thay bằng 1 dòng trạng thái đơn giản.
                    if order.trangThai == .huy {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textFaint)
                            Text("Đơn đã huỷ").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textFaint)
                        }
                    } else {
                        timeline
                    }
                }
                Divider()

                section {
                    Text("Thông tin nhận hàng").font(.system(size: 15, weight: .bold))
                    if order.phanLoai == "Ship" {
                        iconRow("mappin.and.ellipse", "Nhận hàng tại", order.diaChiText ?? "—")
                        if let sdt = order.soDienThoaiText { iconRow("phone.fill", "Số điện thoại", sdt) }
                    } else {
                        iconRow("storefront.fill", "Hình thức", order.phanLoai == "Mv" ? "Mang về" : "Tại quán\(order.tenBan.map { " — Bàn \($0)" } ?? "")")
                    }
                    if let ghiChuRieng, !ghiChuRieng.isEmpty {
                        iconRow("note.text", "Ghi chú", ghiChuRieng)
                    }
                }
                Divider()

                // Style lại danh sách sản phẩm (feedback 2026-09-28) — thêm Divider mảnh giữa các món
                // (trước đây chỉ cách nhau bằng padding, khó phân biệt món liền kề khi cuộn nhanh),
                // "x{n}" chuyển hẳn lên góc trên cùng bên phải NGANG HÀNG với tên món thay vì đứng lẻ
                // loi giữa khoảng trống bên phải như bản trước, khớp cách bố trí ở ảnh mẫu tham khảo hơn.
                section {
                    HStack {
                        Text("Danh sách sản phẩm").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text("\(order.items.reduce(0) { $0 + $1.soLuong }) ly")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.primary)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.primaryTint).clipShape(Capsule())
                    }
                    // Sắp lại hàng món (feedback 2026-09-28): số lượng đi NGAY SAU tên món (cùng 1
                    // dòng, kiểu "Cà Phê Muối x2") thay vì tách riêng góc phải; số tiền chuyển LÊN
                    // GÓC TRÊN PHẢI thay đúng chỗ số lượng cũ, bỏ hẳn dòng giá riêng bên dưới.
                    VStack(spacing: 0) {
                        ForEach(Array(order.items.enumerated()), id: \.element.id) { index, it in
                            HStack(alignment: .top, spacing: 10) {
                                itemThumbnail(it)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("\(it.tenSanPham)\(bienTheSuffix(it.tenBienThe)) x\(it.soLuong)")
                                            .font(.system(size: 15, weight: .bold))
                                        Spacer(minLength: 6)
                                        Text(formatTien(Double(it.soLuong) * (it.donGia + it.toppings.reduce(0) { $0 + $1.gia * Double($1.soLuong) })))
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    if !it.toppings.isEmpty {
                                        Text("+ " + it.toppings.map { $0.soLuong > 1 ? "\($0.ten) x\($0.soLuong)" : $0.ten }.joined(separator: ", ")).font(.system(size: 12)).foregroundColor(Theme.primary)
                                    }
                                    if let ghiChu = it.ghiChu, !ghiChu.isEmpty {
                                        Text("Ghi chú: \(ghiChu)").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            if index < order.items.count - 1 { Divider() }
                        }
                    }
                }
                Divider()

                section {
                    Text("Thông tin thanh toán").font(.system(size: 15, weight: .bold))
                    // Hình thức thanh toán chuyển vào ĐÂY (feedback 2026-09-28: "chưa thể hiện khách
                    // thanh toán tiền mặt hay chuyển khoản") — hợp lý hơn khi đứng cạnh Tổng tiền/Đã
                    // thu/CÒN LẠI thay vì ở mục "Thông tin nhận hàng" như bản trước. Ưu tiên sự thật đã
                    // thu (hinhThucThanhToanHienThi) hơn dự định ban đầu của khách.
                    if let httt = hinhThucThanhToanHienThi {
                        iconRow("creditcard.fill", "Hình thức thanh toán", httt)
                    }
                    infoRow("Tổng tiền", order.tongTien)
                    // Giảm giá = 0 thì Tổng tiền và Thành tiền LUÔN bằng nhau — bớt hẳn dòng "Thành
                    // tiền" trùng lặp trong trường hợp đó (feedback 2026-09-28: "nếu tổng tiền và
                    // thành tiền bằng nhau thì nên bớt đi 1 dòng").
                    if order.giamGia > 0 {
                        infoRow("Giảm giá", order.giamGia)
                        infoRow("Thành tiền", order.thanhTien)
                    }
                    infoRow("Đã thu", order.daThu)
                    Divider()
                    HStack {
                        Text("CÒN LẠI").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textMuted)
                        Spacer()
                        Text(formatTien(order.conLai)).font(.system(size: 20, weight: .bold))
                            .foregroundColor(order.conLai > 0 ? Theme.danger : Theme.success)
                    }
                }

                VStack(spacing: 10) {
                    if order.trangThai != .hoanTat && order.trangThai != .huy {
                        Button("💳 Thanh toán") { donHangPath.append(.thanhToan(hoaDonId: order.id)) }
                            .buttonStyle(.gradientProminent).frame(maxWidth: .infinity)
                    }

                    if order.trangThai == .choXacNhan {
                        Button(role: .destructive) { showHuyConfirm = true } label: {
                            if dangHuy { ProgressView() } else { Text("Huỷ đơn").frame(maxWidth: .infinity) }
                        }
                        .buttonStyle(.bordered).disabled(dangHuy)
                    }
                }
                .padding(.top, 14)

            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("Chi tiết đơn hàng")
        .navigationBarTitleDisplayMode(.inline)
        // "Đặt lại" chuyển lên toolbar góc trên phải — LUÔN NỔI khi cuộn (feedback 2026-09-28), thay
        // vì nằm cuối mục "Thông tin thanh toán" như trước (phải cuộn hết trang mới thấy).
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Đặt lại") { datLai() }
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .task { await reload() }
        .confirmationDialog("Huỷ đơn \(order.maHoaDon)?", isPresented: $showHuyConfirm, titleVisibility: .visible) {
            Button("Huỷ đơn", role: .destructive) { Task { await huyDon() } }
            Button("Không", role: .cancel) {}
        } message: {
            Text("Đơn sẽ bị huỷ, không thể hoàn tác.")
        }
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    @ViewBuilder
    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ảnh món (tham khảo layout Long Châu — ảnh thumbnail bên trái mỗi dòng sản phẩm, 2026-09-28)
    /// thay cho badge số tròn trước đây — fallback icon ly khi món chưa gắn hinhAnh, khớp
    /// OrderStatusView.firstItemImage.
    @ViewBuilder
    private func itemThumbnail(_ it: DonHangKhachItem) -> some View {
        if let hinhAnh = it.hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Theme.primaryTint).frame(width: 56, height: 56)
                .overlay(Image(systemName: "cup.and.saucer.fill").foregroundColor(Theme.primary))
        }
    }

    private func infoRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).foregroundColor(Theme.textMuted)
            Spacer()
            Text(formatTien(value))
        }
    }

    /// Hàng thông tin có icon dẫn đầu — tham khảo style "Thông tin nhận hàng" (icon người/ghim/đồng
    /// hồ) trong ảnh mẫu Long Châu, dùng chung cho cả địa chỉ/SĐT/hình thức thanh toán/ghi chú thay vì
    /// mỗi loại 1 kiểu Text rời rạc như trước (feedback 2026-09-28: "các thông tin dưới cần style lại").
    private func iconRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Theme.textFaint).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12)).foregroundColor(Theme.textFaint)
                Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
            }
        }
    }

    /// GhiChu backend chỉ có 1 field free-text — hình thức thanh toán được gắn làm TIỀN TỐ lúc đặt
    /// đơn (xem CheckoutView.datHang: "🟡 Đã thanh toán bằng Xu" / "💵 Thanh toán khi nhận hàng" /
    /// "📱 Chuyển khoản QR", nối " — {ghi chú thật}" nếu khách có nhập). Tách lại đúng 3 tiền tố này để
    /// hiện riêng "Hình thức thanh toán" thay vì gộp chung 1 dòng "Ghi chú: ..." khó đọc. Đơn tạo qua
    /// Desktop (Tại Chỗ/Mv) không đi qua quy ước này nên không có tiền tố — hinhThucThanhToanText trả
    /// nil, phần "Hình thức thanh toán" tự ẩn, chỉ hiện ghiChu thô như cũ.
    private static let hinhThucThanhToanPrefixes = ["🟡 Đã thanh toán bằng Xu", "💵 Thanh toán khi nhận hàng", "📱 Chuyển khoản QR"]

    private var hinhThucThanhToanText: String? {
        guard let ghiChu = order.ghiChu else { return nil }
        return Self.hinhThucThanhToanPrefixes.first { ghiChu.hasPrefix($0) }
    }

    private var ghiChuRieng: String? {
        guard let ghiChu = order.ghiChu, !ghiChu.isEmpty else { return nil }
        guard let prefix = hinhThucThanhToanText else { return ghiChu }
        var rest = String(ghiChu.dropFirst(prefix.count))
        let sep = " — "
        if rest.hasPrefix(sep) { rest.removeFirst(sep.count) }
        return rest.isEmpty ? nil : rest
    }

    /// Ưu tiên SỰ THẬT đã thu (order.daThuBangChuyenKhoan — tính từ ChiTietHoaDonThanhToans thật,
    /// xem DatHangService) hơn hẳn "hình thức thanh toán" khách tự khai lúc đặt đơn (hinhThucThanhToanText)
    /// — feedback 2026-09-28: "Thông tin thanh toán chưa thể hiện tiền mặt hay chuyển khoản". Khách có
    /// thể đổi ý lúc thu tiền thật (chọn QR nhưng trả tiền mặt tại quầy) nên 2 nguồn có thể lệch nhau,
    /// đã thu thì lấy đúng cái đã xảy ra; CHƯA thu (daThuBangChuyenKhoan == nil) thì mới rơi về hiển thị
    /// dự định ban đầu của khách.
    private var hinhThucThanhToanHienThi: String? {
        if let daCK = order.daThuBangChuyenKhoan {
            return daCK ? "Chuyển khoản" : "Tiền mặt"
        }
        return hinhThucThanhToanText
    }

    /// Mốc thời gian từng bước — nil nghĩa đơn chưa tới bước đó (backend chỉ trả giá trị khi bước đã
    /// xảy ra, xem NgayXacNhanOnline/NgayShip/NgayHoanTat trong DatHangService.GetDonCuaToiAsync).
    private func stepTime(_ i: Int) -> String? {
        switch i {
        case 0: return order.ngayGio
        case 1: return order.ngayXacNhanOnline
        case 2: return order.ngayShip
        case 3: return order.ngayHoanTat
        default: return nil
        }
    }

    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let hhmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return f
    }()

    /// Giờ hiện dưới mỗi chấm stepper — CÙNG NGÀY với lúc tạo đơn thì chỉ cần HH:mm (đầu trang đã
    /// hiện đủ ngày tháng rồi, lặp lại ở cả 4 bước là dư — feedback 2026-09-28: "nếu cùng ngày thì
    /// chỉ cần hiển thị giờ ở dưới các chẹc"). Khác ngày (đơn/thanh toán kéo dài qua hôm sau) vẫn hiện
    /// đủ HH:mm dd-MM-yyyy như formatThongBaoTime để khỏi hiểu lầm bước đó xảy ra ngày nào.
    private func stepTimeDisplay(_ raw: String) -> String {
        let truncated = String(raw.prefix(19))
        guard let date = Self.isoParser.date(from: truncated),
              let ngayTao = Self.isoParser.date(from: String(order.ngayGio.prefix(19))) else {
            return formatThongBaoTime(raw)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        return cal.isDate(date, inSameDayAs: ngayTao) ? Self.hhmmFormatter.string(from: date) : formatThongBaoTime(raw)
    }

    /// Stepper NGANG kiểu Long Châu (tham khảo ảnh chụp 2026-09-28) thay cho timeline dọc trước đây —
    /// hàng chấm tròn/dấu check + đường nối riêng ở trên, hàng nhãn ngắn (nhanNgan) + giờ riêng ở
    /// dưới, mỗi cột chia đều 1/4 chiều ngang. Tách 2 hàng (không lồng nhãn ngay dưới từng chấm trong
    /// cùng 1 VStack) vì chiều cao nhãn 1-2 dòng khác nhau giữa các bước sẽ kéo lệch đường nối ngang
    /// nếu gộp chung.
    ///
    /// Mỗi cột (cả hàng chấm lẫn hàng nhãn) đều `.frame(maxWidth: .infinity)` NHƯ NHAU nên 2 hàng
    /// chia đúng cùng 1 lưới cột — nhưng riêng hàng chấm còn phải tự canh chấm vào ĐÚNG GIỮA cột đó:
    /// bọc chấm giữa 2 đoạn Rectangle `.frame(maxWidth: .infinity)` bằng nhau (đoạn đầu/cuối trong
    /// suốt) để chấm luôn nằm chính giữa bất kể đoạn nối 2 bên dài ngắn khác nhau (fix feedback
    /// 2026-09-28: "chữ chưa canh giữa với check" — trước chấm+đường nối gộp chung 1 Group không có
    /// frame riêng nên trôi lệch khỏi tâm cột nhãn bên dưới).
    private var timeline: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, _ in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(i == 0 ? Color.clear : (i - 1 < currentStep ? Theme.primary : Theme.divider))
                            .frame(maxWidth: .infinity)
                            .frame(height: 2)
                        ZStack {
                            Circle()
                                .fill(i <= currentStep ? Theme.primary : Color.clear)
                                .overlay(Circle().stroke(i <= currentStep ? Theme.primary : Theme.divider, lineWidth: 1.5))
                            if i <= currentStep {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Rectangle()
                            .fill(i == steps.count - 1 ? Color.clear : (i < currentStep ? Theme.primary : Theme.divider))
                            .frame(maxWidth: .infinity)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    VStack(spacing: 2) {
                        Text(step.nhanNgan)
                            .font(.system(size: 11, weight: i <= currentStep ? .semibold : .regular))
                            .foregroundColor(i <= currentStep ? .primary : Theme.textFaint)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if let raw = stepTime(i) {
                            Text(stepTimeDisplay(raw))
                                .font(.system(size: 9)).foregroundColor(Theme.textFaint)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func reload() async {
        let list = await APIClient.shared.getDonCuaToi()
        guard let moi = list.first(where: { $0.id == order.id }) else { return }
        order = moi
    }

    private func huyDon() async {
        dangHuy = true
        defer { dangHuy = false }
        let result = await APIClient.shared.huyDon(order.id)
        if result.success { dismiss() }
    }

    private func datLai() {
        cart.clear()
        for it in order.items {
            cart.addItem(sanPhamBienTheId: it.sanPhamBienTheId, tenSanPham: it.tenSanPham, tenBienThe: it.tenBienThe, giaBan: it.donGia, soLuong: it.soLuong, ghiChu: it.ghiChu, toppings: it.toppings.map { CartTopping(id: $0.toppingId, ten: $0.ten, gia: $0.gia, soLuong: $0.soLuong) }, sanPhamId: it.sanPhamId)
        }
        cart.markDatLai()
        cartPath = []
        selectedTab = .cart
    }
}
