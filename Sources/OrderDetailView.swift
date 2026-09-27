import SwiftUI

/// Port từ OrderDetailScreen.tsx — timeline trạng thái, danh sách món, tổng kết tiền, huỷ/đặt lại/
/// đánh giá đơn.
struct OrderDetailView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var donHangPath: [DonHangRoute]
    @Binding var selectedTab: AppTab
    @Binding var cartPath: [HomeRoute]
    @Environment(\.dismiss) private var dismiss

    @State var order: DonHangKhach

    @State private var daDanhGia = false
    @State private var soSaoDaDanh = 0
    @State private var pickSao = 0
    @State private var nhanXet = ""
    @State private var dangGui = false
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
                    Text(order.phanLoai == "Ship" ? "Giao đến" : "Hình thức").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
                    if order.phanLoai == "Ship" {
                        Text(order.diaChiText ?? "—")
                        if let sdt = order.soDienThoaiText { Text("SĐT: \(sdt)").foregroundColor(Theme.textMuted).font(.system(size: 13)) }
                    } else {
                        Text(order.phanLoai == "Mv" ? "Mang về" : "Tại quán\(order.tenBan.map { " — Bàn \($0)" } ?? "")")
                    }
                    if let ghiChu = order.ghiChu, !ghiChu.isEmpty {
                        Text("Ghi chú: \(ghiChu)").foregroundColor(Theme.textMuted).font(.system(size: 13))
                    }
                }
                Divider()

                section {
                    HStack {
                        Label("Món", systemImage: "cup.and.saucer.fill")
                        Spacer()
                        Text("\(order.items.reduce(0) { $0 + $1.soLuong }) ly")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.primary)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.primaryTint).clipShape(Capsule())
                    }
                    ForEach(order.items) { it in
                        HStack(alignment: .top, spacing: 10) {
                            itemThumbnail(it)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(it.tenSanPham)\(bienTheSuffix(it.tenBienThe))").font(.system(size: 15, weight: .bold))
                                if !it.toppings.isEmpty {
                                    Text("+ " + it.toppings.map { $0.soLuong > 1 ? "\($0.ten) x\($0.soLuong)" : $0.ten }.joined(separator: ", ")).font(.system(size: 12)).foregroundColor(Theme.primary)
                                }
                                if let ghiChu = it.ghiChu, !ghiChu.isEmpty {
                                    Text("Ghi chú: \(ghiChu)").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                                }
                                Text(formatTien(Double(it.soLuong) * (it.donGia + it.toppings.reduce(0) { $0 + $1.gia * Double($1.soLuong) }))).font(.system(size: 15, weight: .bold))
                            }
                            Spacer(minLength: 0)
                            Text("x\(it.soLuong)").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMuted)
                        }
                        .padding(.vertical, 6)
                    }
                }
                Divider()

                section {
                    infoRow("Tổng tiền", order.tongTien)
                    if order.giamGia > 0 { infoRow("Giảm giá", order.giamGia) }
                    infoRow("Thành tiền", order.thanhTien)
                    infoRow("Đã thu", order.daThu)
                    Divider()
                    HStack {
                        Text("CÒN LẠI").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textMuted)
                        Spacer()
                        Text(formatTien(order.conLai)).font(.system(size: 20, weight: .bold))
                            .foregroundColor(order.conLai > 0 ? Theme.danger : Theme.success)
                    }
                    // "Đặt lại" gộp vào mục tổng tiền thay vì đứng riêng bên dưới (feedback 2026-09-24)
                    // — nằm cạnh số tiền của CHÍNH đơn này, đỡ trôi nổi xa nội dung liên quan.
                    Button("Đặt lại") { datLai() }
                        .buttonStyle(.gradientProminent).frame(maxWidth: .infinity)
                        .padding(.top, 4)
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

                if order.trangThai == .hoanTat {
                    Divider().padding(.top, 14)
                    section { danhGiaSection }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("Chi tiết đơn hàng")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            daDanhGia = order.daDanhGia
            soSaoDaDanh = order.soSaoDaDanh ?? 0
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

    @ViewBuilder
    private var danhGiaSection: some View {
        // "+100 Xu" khớp DanhGiaDonThuong (DatHangService.cs) — đổi số ở backend thì nhớ sửa cả đây.
        Text(daDanhGia ? "Đánh giá" : "Đánh giá — nhận 100 Xu")
            .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
        if daDanhGia {
            Text("Bạn đã đánh giá \(String(repeating: "⭐", count: soSaoDaDanh)) — Cảm ơn bạn!")
        } else {
            HStack {
                ForEach(1...5, id: \.self) { n in
                    Button { pickSao = n } label: {
                        // Glyph "☆" mặc định quá mờ trên nền card xám (feedback 2026-09-24) — ép màu
                        // rõ hơn thay vì để hệ thống tự chọn (foregroundColor mặc định nhạt gần trắng).
                        Text(n <= pickSao ? "⭐" : "☆")
                            .font(.system(size: 28))
                            .foregroundColor(n <= pickSao ? nil : Theme.textMuted)
                    }
                }
            }
            TextField("Nhận xét (không bắt buộc)", text: $nhanXet).textFieldStyle(.roundedBorder).tint(Theme.primary)
            Button {
                Task { await guiDanhGia() }
            } label: {
                if dangGui { ProgressView().tint(.white) } else { Text("Gửi đánh giá").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.gradientProminent).disabled(pickSao == 0 || dangGui)
        }
    }

    private func reload() async {
        let list = await APIClient.shared.getDonCuaToi()
        guard let moi = list.first(where: { $0.id == order.id }) else { return }
        order = moi
        if moi.daDanhGia {
            daDanhGia = true
            soSaoDaDanh = moi.soSaoDaDanh ?? 0
        }
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

    private func guiDanhGia() async {
        guard pickSao > 0 else { return }
        dangGui = true
        defer { dangGui = false }
        let result = await APIClient.shared.danhGiaDon(hoaDonId: order.id, soSao: pickSao, nhanXet: nhanXet.isEmpty ? nil : nhanXet)
        if result.success {
            daDanhGia = true
            soSaoDaDanh = pickSao
        }
    }
}
