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
    @State private var dangMoQuaId: String?
    @State private var alertMessage: (title: String, message: String)?

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Đơn hàng", icon: "shippingbox", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if orders.isEmpty {
                    Text("Chưa có đơn hàng nào.").foregroundColor(Theme.textFaint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                            cardRow(topExtra: index == 0 ? 6 : 0) { orderCard(order) }
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
    private func orderCardContent(_ item: DonHangKhach) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.maHoaDon).fontWeight(.bold)
                Spacer()
                Text(item.ngayGio).font(.system(size: 12)).foregroundColor(Theme.textFaint)
            }
            Text(item.tenMonSummary).font(.system(size: 14)).foregroundColor(Theme.textMuted)
            HStack {
                Text(formatTien(item.thanhTien)).font(.system(size: 16, weight: .bold))
                Spacer()
                Text(item.trangThai.nhan)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(item.trangThai.mau)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { path.append(.detail(item)) }
    }

    private func orderCard(_ item: DonHangKhach) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            orderCardContent(item)
            actionRow(item)
        }
        .cardBoxStyle()
    }

    /// Nút hành động góc dưới bên phải mỗi card — hiện tuỳ trạng thái đơn: "Mở quà" chỉ hiện cho đơn
    /// Nhận tại quán đã hoàn tất và chưa mở; "Thanh toán" chỉ hiện khi còn nợ; "Đặt lại" luôn hiện.
    private func actionRow(_ item: DonHangKhach) -> some View {
        HStack(spacing: 8) {
            Spacer()
            if item.trangThai == .hoanTat && item.diaChiText == "Nhận tại quán" && !item.daMoQuaXu {
                actionButton("🎁 Mở quà", loading: dangMoQuaId == item.id) {
                    Task { await moQua(item) }
                }
            }
            actionButton("🔁 Đặt lại") { datLai(item) }
            if item.trangThai != .hoanTat {
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

    private func moQua(_ order: DonHangKhach) async {
        dangMoQuaId = order.id
        defer { dangMoQuaId = nil }
        let res = await APIClient.shared.moQuaNhanTaiQuan(hoaDonId: order.id)
        if res.isSuccess, let data = res.data {
            alertMessage = data.trung ? ("🎉 Chúc mừng!", data.label) : ("Kết quả", data.label)
            await load(silent: true)
        } else {
            alertMessage = ("Chưa mở được", res.message ?? "Có lỗi xảy ra, thử lại nhé.")
        }
    }
}
