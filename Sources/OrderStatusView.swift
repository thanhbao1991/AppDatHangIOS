import SwiftUI

/// Port từ OrderStatusScreen.tsx — poll 10s khi màn hình đang mở (bản đầu chưa cần SignalR/push).
private let pollInterval: TimeInterval = 10

struct OrderStatusView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [DonHangRoute]
    @Binding var selectedTab: AppTab
    @Binding var cartPath: [HomeRoute]
    var notificationBell: AnyView

    @State private var orders: [DonHangKhach] = []
    @State private var loading = true
    @State private var pollTask: Task<Void, Never>?
    @State private var alertMessage: (title: String, message: String)?
    // Lọc nhanh theo nhóm kiểu Long Châu (2026-09-23) — nil = xem tất cả. Bấm lại đúng icon đang chọn
    // để bỏ lọc, giống hành vi toggle chip lọc quen thuộc ở CatalogView.
    @State private var filter: NhomDonHang?

    private var filteredOrders: [DonHangKhach] {
        guard let filter else { return orders }
        return orders.filter { $0.trangThai.nhom == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Đơn hàng", icon: "shippingbox", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    fullScreenLoading()
                } else if orders.isEmpty {
                    Text("Chưa có đơn hàng nào.").foregroundColor(Theme.textFaint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 2026-09-26: thử đổi sang dạng PHẲNG (không card trắng bo góc) giống Lịch sử Xu
                    // — List(.plain) mặc định, đường kẻ ngang giữa các đơn thay cho card riêng biệt.
                    // Chỉ đổi RIÊNG màn này, không đụng cardBox/cardRow/cardListBackground (Theme.swift)
                    // vì các tab khác (Giỏ hàng/Ưu đãi/Tài khoản) vẫn đang dùng style card chung đó.
                    List {
                        nhomFilterCard
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        if filteredOrders.isEmpty {
                            Text("Không có đơn nào ở mục này.")
                                .font(.system(size: 13)).foregroundColor(Theme.textFaint)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(filteredOrders, id: \.id) { order in
                                orderCard(order)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await load(silent: true) }
                }
            }
        }
        .task {
            await load()
            startPolling()
        }
        .onDisappear { pollTask?.cancel() }
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    /// Nội dung chính của card — bấm vào đây (KHÔNG phải cả card) mới mở chi tiết đơn, để hàng nút
    /// hành động (actionRow) bên dưới có vùng chạm riêng, không bị .onTapGesture của cha nuốt mất
    /// (cùng bài học nút X trong GioHangView.itemRow — Button con cần .buttonStyle(.plain) mới thắng).
    /// Layout theo phong cách Shopee (ảnh mẫu 2026-09-24): ảnh món đầu tiên bên trái, tên các món
    /// viết liền 1 dòng (tenMonSummary server đã join sẵn bằng ", "), tổng tiền + số sản phẩm căn phải
    /// phía dưới. Dòng đầu bỏ mã hoá đơn (vô nghĩa với khách, cùng lý do đã bỏ ở LichSuCongNoView
    /// feedback 2026-09-22) — thay bằng phân loại (kèm địa chỉ nếu là đơn Ship). Trạng thái chỉ còn
    /// text màu, không nền, đỡ rối mắt cạnh phân loại (2026-09-24).
    private func orderCardContent(_ item: DonHangKhach) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(phanLoaiLine(item)).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textMuted).lineLimit(2)
                Spacer()
                Text(item.trangThai.nhan)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(item.trangThai.mau)
                    .lineLimit(1)
            }
            HStack(alignment: .top, spacing: 12) {
                firstItemImage(item)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.tenMonSummary)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    // ngayGio là ISO thô server trả (vd "2026-09-17T19:12:03.8821513") — dùng lại
                    // formatThongBaoTime (ThongBaoView.swift) cho gọn kiểu "Hôm nay, HH:mm" thay vì
                    // lộ hẳn timestamp kỹ thuật ra UI khách hàng.
                    Text(formatThongBaoTime(item.ngayGio)).font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                Spacer()
                Text("Tổng số tiền (\(tongSoLuong(item)) sản phẩm):").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                Text(formatTien(item.thanhTien)).font(.system(size: 16, weight: .bold))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { path.append(.detail(item)) }
    }

    /// Ảnh món đầu tiên trong đơn (kiểu ảnh sản phẩm ở card Shopee) — fallback icon ly khi món cũ
    /// chưa gắn hinhAnh hoặc đơn không có món nào (không nên xảy ra nhưng tránh crash/để trống xấu).
    @ViewBuilder
    private func firstItemImage(_ item: DonHangKhach) -> some View {
        if let hinhAnh = item.items.first?.hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Theme.primaryTint).frame(width: 56, height: 56)
                .overlay(Image(systemName: "cup.and.saucer.fill").foregroundColor(Theme.primary))
        }
    }

    private func tongSoLuong(_ item: DonHangKhach) -> Int {
        item.items.reduce(0) { $0 + $1.soLuong }
    }

    /// Cùng cách map PhanLoai ("Ship"/"Mv"/khác) với OrderDetailView/LichSuCongNoView — đơn Ship có
    /// địa chỉ thì gộp luôn "Giao hàng tại: ..." thay vì tách riêng nhãn + dòng địa chỉ, đỡ dư dòng.
    private func phanLoaiLine(_ item: DonHangKhach) -> String {
        if item.phanLoai == "Ship", let diaChi = item.diaChiText?.trimmingCharacters(in: .whitespaces), !diaChi.isEmpty {
            return "Giao hàng tại: \(diaChi)"
        }
        switch item.phanLoai {
        case "Ship": return "Giao hàng"
        case "Mv": return "Mang về"
        default: return item.tenBan.map { "Tại quán — Bàn \($0)" } ?? "Tại quán"
        }
    }

    /// Banner gợi ý đánh giá kiểu Shopee ("Đánh giá sản phẩm trước ... để nhận Xu") — chỉ hiện khi
    /// đơn đã hoàn tất và khách chưa đánh giá. 100 Xu khớp DanhGiaDonThuong (DatHangService.cs) —
    /// đổi số ở backend thì nhớ sửa cả đây (chưa có endpoint trả cấu hình này về app).
    private func danhGiaBanner(_ item: DonHangKhach) -> some View {
        Button { path.append(.detail(item)) } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill").font(.system(size: 18)).foregroundColor(Theme.warning)
                Text("Đánh giá sản phẩm để nhận **100 Xu**")
                    .font(.system(size: 13)).foregroundColor(Theme.textMuted)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textFaint)
            }
            .padding(10)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// 2026-09-26: đổi từ 4 icon kiểu Long Châu sang tab chữ + gạch chân — khớp đúng cấu trúc tabBar
    /// của LichSuViView (Lịch sử Xu), theo phản hồi "filter chưa giống lịch sử xu, bỏ icon chuyển
    /// sang flat". Badge đỏ số lượng "Đang xử lý" giữ nguyên, chuyển thành hình tròn nhỏ cạnh chữ.
    private var nhomFilterCard: some View {
        HStack(spacing: 0) {
            ForEach(NhomDonHang.allCases) { nhom in
                nhomButton(nhom)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.systemBackground))
    }

    private func nhomButton(_ nhom: NhomDonHang) -> some View {
        let count = orders.filter { $0.trangThai.nhom == nhom }.count
        let selected = filter == nhom
        return Button {
            filter = selected ? nil : nhom
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(nhom.nhan)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selected ? Theme.primary : Theme.textMuted)
                    if nhom == .dangXuLy && count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(4).background(Theme.danger).clipShape(Circle())
                    }
                }
                Rectangle()
                    .fill(selected ? Theme.primary : Color.clear)
                    .frame(height: 2)
            }
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    private func orderCard(_ item: DonHangKhach) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            orderCardContent(item)
            if item.trangThai == .hoanTat && !item.daDanhGia {
                danhGiaBanner(item)
            }
            actionRow(item)
        }
        // KHÔNG thêm .padding(.horizontal) riêng — List đã tự có inset ngang mặc định, cộng thêm nữa
        // sẽ bị double padding khiến hàng đơn hẹp hơn hẳn Lịch sử Xu (LichSuViView không thêm padding
        // ngang cho hàng, chỉ dựa đúng 1 lớp inset mặc định của List).
        .padding(.vertical, 10)
    }

    /// Hàng dưới cùng mỗi card — góc trái hiện KẾT QUẢ đánh giá (đơn đã đánh giá rồi, không cần nút
    /// nữa), góc phải là nút hành động. Đổi thứ tự 2 nút 2026-09-24: "Đánh giá"/"Thanh toán" đứng
    /// TRƯỚC "Đặt lại" (trước đây "Đặt lại" luôn đứng đầu bên trái, nay nhường vị trí ngoài cùng —
    /// dễ bấm nhất bằng ngón cái — cho nút cần hành động gấp hơn).
    private func actionRow(_ item: DonHangKhach) -> some View {
        HStack(spacing: 8) {
            if item.daDanhGia {
                Text(String(repeating: "⭐", count: item.soSaoDaDanh ?? 0))
                    .font(.system(size: 13))
            }
            Spacer()
            if item.trangThai == .hoanTat && !item.daDanhGia {
                actionButton("⭐ Đánh giá", filled: true) { path.append(.detail(item)) }
            } else if item.trangThai != .hoanTat && item.trangThai != .huy {
                actionButton("💳 Thanh toán", filled: true) { path.append(.thanhToan(hoaDonId: item.id)) }
            }
            actionButton("Đặt lại", filled: true) { datLai(item) }
        }
    }

    private func actionButton(_ label: String, filled: Bool = false, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if loading {
                ProgressView().scaleEffect(0.7).frame(height: 14)
                    .padding(.horizontal, 14).padding(.vertical, 6)
            } else {
                Text(label).font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(filled ? .white : Theme.primary)
        // filled=true là nút "💳 Thanh toán" — cùng vai trò CTA như nút cùng tên bên OrderDetailView
        // (đã đổi gradient), lúc trước tưởng đây là chip lọc trạng thái nên bỏ sót.
        .background(filled ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.primaryTint))
        .clipShape(Capsule())
        .disabled(loading)
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true }
        let result = await APIClient.shared.getDonCuaToi()
        orders = result
        loading = false
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await load(silent: true)
            }
        }
    }

    private func datLai(_ order: DonHangKhach) {
        cart.clear()
        for it in order.items {
            cart.addItem(sanPhamBienTheId: it.sanPhamBienTheId, tenSanPham: it.tenSanPham, tenBienThe: it.tenBienThe, giaBan: it.donGia, soLuong: it.soLuong, ghiChu: it.ghiChu, toppings: it.toppings.map { CartTopping(id: $0.toppingId, ten: $0.ten, gia: $0.gia, soLuong: $0.soLuong) }, sanPhamId: it.sanPhamId)
        }
        cart.markDatLai()
        cartPath = []
        selectedTab = .cart
    }

}
