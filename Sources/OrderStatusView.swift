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
                    List {
                        cardRow(topExtra: 6) { nhomFilterCard }
                        if filteredOrders.isEmpty {
                            Text("Không có đơn nào ở mục này.")
                                .font(.system(size: 13)).foregroundColor(Theme.textFaint)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                        } else {
                            ForEach(filteredOrders, id: \.id) { order in
                                cardRow { orderCard(order) }
                            }
                        }
                    }
                    .cardListBackground()
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
    /// viết liền 1 dòng (tenMonSummary server đã join sẵn bằng ", "), badge trạng thái góc trên phải,
    /// tổng tiền + số sản phẩm căn phải phía dưới.
    private func orderCardContent(_ item: DonHangKhach) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.maHoaDon).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textMuted)
                Spacer()
                Text(item.trangThai.nhan)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(item.trangThai.mau)
                    .clipShape(Capsule())
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

    /// Card "Đơn của tôi" 4 icon kiểu Long Châu (ảnh mẫu người dùng gửi 2026-09-23) — mục 4 đổi thành
    /// "Đã huỷ" thay vì "Đổi/Trả" (app không có tính năng đổi/trả). Badge đỏ số lượng chỉ hiện ở
    /// "Đang xử lý" (đơn cần khách theo dõi/hành động), giống cách Long Châu chỉ badge mục đầu tiên.
    private var nhomFilterCard: some View {
        cardBox {
            HStack(spacing: 0) {
                ForEach(NhomDonHang.allCases) { nhom in
                    nhomButton(nhom)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func nhomButton(_ nhom: NhomDonHang) -> some View {
        let count = orders.filter { $0.trangThai.nhom == nhom }.count
        let selected = filter == nhom
        return Button {
            filter = selected ? nil : nhom
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: nhom.icon)
                        .font(.system(size: 22))
                        .foregroundColor(selected ? Theme.primary : Theme.textMuted)
                        .frame(width: 32, height: 32)
                    if nhom == .dangXuLy && count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(4).background(Theme.danger).clipShape(Circle())
                            .offset(x: 8, y: -6)
                    }
                }
                Text(nhom.nhan)
                    .font(.system(size: 12, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.primary : Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
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
        .cardBoxStyle()
    }

    /// Nút hành động góc dưới bên phải mỗi card — hiện tuỳ trạng thái đơn: "Thanh toán" chỉ hiện khi
    /// còn nợ; "Đánh giá" chỉ hiện khi đơn hoàn tất và chưa đánh giá; "Đặt lại" luôn hiện.
    private func actionRow(_ item: DonHangKhach) -> some View {
        HStack(spacing: 8) {
            Spacer()
            actionButton("Đặt lại", filled: true) { datLai(item) }
            if item.trangThai == .hoanTat && !item.daDanhGia {
                actionButton("⭐ Đánh giá", filled: true) { path.append(.detail(item)) }
            } else if item.trangThai != .hoanTat && item.trangThai != .huy {
                actionButton("💳 Thanh toán", filled: true) { path.append(.thanhToan(hoaDonId: item.id)) }
            }
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
