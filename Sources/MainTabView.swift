import SwiftUI

/// Port từ MainTabs.tsx — Thực đơn/Giỏ hàng/Đơn hàng/Ưu đãi/Tài khoản + icon chuông Thông báo
/// nhúng làm trailing trong header (SearchBar/TitleBar) của MỌI tab, không còn là tab riêng.
/// Dùng thanh tab TỰ VẼ (không phải `TabView`/`.tabItem` gốc của SwiftUI) — lý do: `.tabItem` là
/// một "trait" SwiftUI gắn vào lúc dựng UITabBarController, closure của nó KHÔNG track @State như
/// body thật, nên đổi `selectedTab` chỉ khiến UIKit tự tint màu, không re-render lại icon sang
/// bản .fill (verify bằng ảnh chụp máy thật, xem commit e4b6068 — bug có thật, không phải hoang
/// tưởng). Tự vẽ tab bar (giống AppQuanLyIOS/MainTabView.swift) để icon đổi outline/fill theo
/// đúng tab đang chọn, vì lúc đó Image nằm trong body thật, được SwiftUI diff lại bình thường.
private let thongBaoPollInterval: TimeInterval = 60

struct MainTabView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var cart = CartStore()

    @State private var selectedTab: AppTab = .home
    @State private var homePath: [HomeRoute] = []
    @State private var cartPath: [HomeRoute] = []
    @State private var donHangPath: [DonHangRoute] = []
    @State private var unreadCount = 0
    @State private var uuDaiCanLam = false
    @State private var pollTask: Task<Void, Never>?
    @State private var showThongBao = false
    @State private var showTaiKhoanBaoMat = false
    @State private var showLogin = false
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared

    /// true khi trang Thanh toán (CheckoutView) đang mở ở tab Thực đơn HOẶC Giỏ hàng (2 chỗ duy nhất
    /// có thể push route .checkout, xem navigationDestination bên dưới) — dùng để ẩn tabBar dưới cùng.
    private var isCheckoutActive: Bool {
        homePath.last == .checkout || cartPath.last == .checkout
    }

    /// Badge số tiền giỏ hàng dạng viết tắt trên tab bar (vd "25k", "1.2tr") — nil khi giỏ trống để
    /// ẩn hẳn badge thay vì hiện "0k".
    private var cartBadgeText: String? {
        guard cart.totalCount > 0 else { return nil }
        let total = cart.totalPrice
        if total >= 1_000_000 {
            return String(format: "%.1ftr", total / 1_000_000)
        }
        return "\(Int((total / 1000).rounded()))k"
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack(path: $homePath) {
                        MenuView(path: $homePath, selectedTab: $selectedTab, notificationBell: AnyView(notificationBell))
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .checkout: CheckoutView(path: $homePath, selectedTab: $selectedTab)
                                case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; homePath = [] }
                                }
                            }
                    }
                case .cart:
                    NavigationStack(path: $cartPath) {
                        GioHangView(path: $cartPath, notificationBell: AnyView(notificationBell))
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .checkout: CheckoutView(path: $cartPath, selectedTab: $selectedTab)
                                case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; cartPath = [] }
                                }
                            }
                    }
                case .cart where !isLoggedIn:
                    guestGate("Giỏ hàng", icon: "cart", message: "Đăng nhập để thêm món vào giỏ và đặt hàng.")
                case .donHang where !isLoggedIn:
                    guestGate("Đơn hàng", icon: "shippingbox", message: "Đăng nhập để xem và theo dõi đơn hàng của bạn.")
                case .sanThuong where !isLoggedIn:
                    guestGate("Ưu đãi", icon: "gift", message: "Đăng nhập để điểm danh, mở hộp quà và nhận ưu đãi.")
                case .voucher where !isLoggedIn:
                    guestGate("Voucher", icon: "ticket", message: "Đăng nhập để xem và dùng voucher của bạn.")
                case .settings where !isLoggedIn:
                    guestGate("Tài khoản", icon: "person.crop.circle", message: "Đăng nhập hoặc đăng ký để quản lý tài khoản và tích điểm.")
                case .donHang:
                    NavigationStack(path: $donHangPath) {
                        OrderStatusView(path: $donHangPath, selectedTab: $selectedTab, cartPath: $cartPath, notificationBell: AnyView(notificationBell))
                            .navigationDestination(for: DonHangRoute.self) { route in
                                switch route {
                                case .detail(let order):
                                    OrderDetailView(donHangPath: $donHangPath, selectedTab: $selectedTab, cartPath: $cartPath, order: order)
                                case .thanhToan(let hoaDonId):
                                    ThanhToanView(hoaDonId: hoaDonId) { donHangPath = [] }
                                }
                            }
                    }
                case .sanThuong:
                    NavigationStack {
                        UuDaiView(notificationBell: AnyView(notificationBell))
                    }
                case .voucher:
                    NavigationStack {
                        VoucherCuaToiView(notificationBell: AnyView(notificationBell))
                    }
                case .settings:
                    NavigationStack {
                        SettingsView(isLoggedIn: $isLoggedIn, notificationBell: AnyView(notificationBell), accountSettingsGear: AnyView(accountSettingsGear))
                    }
                }
            }
            // Chevron back button do SwiftUI tự vẽ (không đi qua UINavigationBarAppearance ở
            // AppDatHangIOSApp.init — cái đó chỉ chắc ăn với CHỮ back/tiêu đề) cần .tint() ở tầng
            // SwiftUI mới lên đúng màu trắng, verify thật: thiếu dòng này mũi tên back biến mất dù
            // chữ "Menu" vẫn trắng bình thường. Đặt ở đây (ngoài switch) để áp dụng chung mọi tab,
            // không phải thêm riêng từng NavigationStack — mọi Button/control CÓ set .tint() riêng
            // (vd nút primary màu Theme.primary) vẫn override được bình thường, không bị đè.
            .tint(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Đăng nhập/đăng xuất → dựng lại nội dung tab (tải lại giá riêng, đơn hàng...) nhưng giữ giỏ hàng.
            .id(isLoggedIn)

            // Ẩn hẳn thanh tab dưới cùng khi đang ở trang Thanh toán (CheckoutView) — khớp Shopee:
            // checkout là luồng riêng tách biệt, không cho lỡ tay chuyển tab giữa chừng khi đang điền
            // địa chỉ/chọn thanh toán. Trang này tự vẽ header riêng (ẩn navbar hệ thống) nên tự thân
            // đã chiếm toàn màn hình, ẩn tabBar cho đúng ý đồ đó.
            if !isCheckoutActive {
                Divider()
                tabBar
            }
        }
        .tint(Theme.primary)
        .environmentObject(cart)
        .onReceive(NotificationCenter.default.publisher(for: .yeuCauDangNhap)) { _ in
            if !isLoggedIn { showLogin = true }
        }
        .onChange(of: isLoggedIn) { loggedIn in
            if loggedIn {
                showLogin = false
                Task { await checkUnread(); await checkUuDai() }
            } else {
                cart.clear()
                unreadCount = 0
                uuDaiCanLam = false
                homePath = []; cartPath = []; donHangPath = []
                selectedTab = .home
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            ZStack(alignment: .topTrailing) {
                LoginView(isLoggedIn: $isLoggedIn)
                Button { showLogin = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.white.opacity(0.9))
                        .padding(16)
                }
                .accessibilityLabel("Đóng")
            }
        }
        .onChange(of: selectedTab) { _ in
            showThongBao = false
            showTaiKhoanBaoMat = false
            Task { await checkUuDai() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .uuDaiDaThayDoi)) { _ in
            Task { await checkUuDai() }
        }
        .sheet(isPresented: $showThongBao) {
            NavigationStack {
                ThongBaoView(selectedTab: $selectedTab)
            }
        }
        .sheet(isPresented: $showTaiKhoanBaoMat) {
            NavigationStack {
                TaiKhoanBaoMatView(isLoggedIn: $isLoggedIn)
            }
        }
        .task {
            await checkUnread()
            await checkUuDai()
            startPolling()
        }
        .onDisappear { pollTask?.cancel() }
        .onChange(of: deepLinkRouter.pendingHoaDonId) { hoaDonId in
            guard let hoaDonId else { return }
            deepLinkRouter.pendingHoaDonId = nil
            openDonHang(id: hoaDonId)
        }
    }

    /// Bấm vào push notification -> chuyển tab Đơn hàng, tải lại danh sách rồi push thẳng vào chi
    /// tiết đơn vừa nhận thông báo. Không có API lấy 1 đơn theo id (chỉ có list "don-cua-toi") nên
    /// tải cả list rồi lọc — danh sách tối đa 50 đơn gần nhất, chấp nhận được cho thao tác hiếm khi
    /// này (bấm thông báo), không đáng để thêm endpoint riêng.
    private func openDonHang(id: String) {
        selectedTab = .donHang
        donHangPath = []
        Task {
            let orders = await APIClient.shared.getDonCuaToi()
            guard let order = orders.first(where: { $0.id == id }) else { return }
            donHangPath = [.detail(order)]
        }
    }

    /// Icon chuông đặt làm `trailing` trong header (SearchBar/TitleBar) của TỪNG tab (thay cho tab
    /// "Thông báo" cũ) — mở ThongBaoView qua sheet khi bấm, thay vì chuyển tab. Trước đây thử nổi
    /// bằng `.overlay(alignment: .topTrailing)` trên toàn màn hình nhưng bị đè lên thanh tìm kiếm
    /// (pill trắng) của tab Thực đơn do overlay không cộng dồn layout — đổi hẳn sang truyền xuống
    /// làm trailing thật trong HStack của từng header để không chồng lấn.
    private var notificationBell: some View {
        Button {
            guard isLoggedIn else { showLogin = true; return }
            showThongBao = true
            unreadCount = 0
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        // Viền trắng mỏng quanh badge — trước đây đỏ tươi nằm thẳng trên nền header
                        // đổi màu theo hạng (nâu vàng/đen...) bị chê "chói/gắt", tách bạch bằng viền
                        // trắng cố định thay vì phải chọn lại 1 màu đỏ khác hoà hợp với TỪNG hạng.
                        .overlay(Capsule().stroke(Color.white, lineWidth: 1.2))
                        .offset(x: 6, y: -4)
                }
            }
        }
    }

    /// Icon bánh răng mở TaiKhoanBaoMatView (đổi mật khẩu, thiết bị đăng nhập, đăng xuất, xoá tài
    /// khoản) — chỉ truyền vào header của tab Tài khoản (xem SettingsView), đặt bên phải icon chuông.
    private var accountSettingsGear: some View {
        Button {
            showTaiKhoanBaoMat = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
        }
    }

    /// Màn thay thế cho tab cần tài khoản khi khách chưa đăng nhập (Apple 5.1.1(v)).
    private func guestGate(_ title: String, icon: String, message: String) -> some View {
        VStack(spacing: 0) {
            // Cùng thanh tiêu đề (gradient + chuông) như các tab đã đăng nhập, để khách chưa đăng nhập
            // không thấy màn "trắng trơn" lệch phong cách.
            TitleBar(title: title, icon: icon, centerTitle: true, trailing: AnyView(notificationBell))
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: icon).font(.system(size: 54)).foregroundColor(Theme.primary)
                Text(message).font(.system(size: 15)).foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
                Button { showLogin = true } label: {
                    Text("Đăng nhập / Đăng ký").fontWeight(.bold).frame(minWidth: 220)
                }
                .buttonStyle(.gradientProminent)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, label: "Thực đơn", icon: "cup.and.saucer")
            tabButton(.cart, label: "Giỏ hàng", icon: "cart", badgeText: cartBadgeText)
            tabButton(.donHang, label: "Đơn hàng", icon: "list.bullet.rectangle")
            tabButton(.voucher, label: "Voucher", icon: "ticket")
            tabButton(.sanThuong, label: "Ưu đãi", icon: "gift", showDot: uuDaiCanLam)
            tabButton(.settings, label: "Tài khoản", icon: "person.crop.circle")
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(.bar)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, label: String, icon: String, badgeText: String? = nil, badgeCount: Int = 0, showDot: Bool = false) -> some View {
        let isSelected = selectedTab == tab
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? "\(icon).fill" : icon)
                        .font(.system(size: 20))
                    if let badgeText {
                        tabBadge(badgeText, pulse: tab == .cart)
                    } else if badgeCount > 0 {
                        tabBadge("\(badgeCount)")
                    } else if showDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                            .offset(x: 6, y: -2)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? Theme.primary : Theme.textMuted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func tabBadge(_ text: String, pulse: Bool = false) -> some View {
        Group {
            if pulse {
                PulsingBadge(text: text)
            } else {
                Text(text)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
            }
        }
        .offset(x: 14, y: -8)
    }

    private func checkUnread() async {
        guard isLoggedIn else { return }
        let items = await APIClient.shared.getThongBao()
        guard !items.isEmpty else { return }
        let lastSeen = Prefs.thongBaoLastSeen
        unreadCount = lastSeen.map { seen in items.filter { $0.ngayTao > seen }.count } ?? items.count
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(thongBaoPollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await checkUnread()
                await checkUuDai()
            }
        }
    }

    /// Chấm đỏ trên tab Ưu đãi khi hôm nay còn việc làm: chưa điểm danh HOẶC còn lượt mở hộp quà.
    /// Lỗi mạng (nil) thì giữ nguyên trạng thái cũ, không nhấp nháy tắt/bật.
    private func checkUuDai() async {
        guard isLoggedIn else { return }
        async let dd = APIClient.shared.getDiemDanhInfo()
        async let quay = APIClient.shared.getVongQuayInfo()
        let (ddInfo, quayInfo) = await (dd, quay)
        guard ddInfo != nil || quayInfo != nil else { return }
        uuDaiCanLam = (ddInfo.map { !$0.daDiemDanhHomNay } ?? false) || ((quayInfo?.soLuotConLai ?? 0) > 0)
    }
}

/// Badge nhấp nháy (phóng to/thu nhỏ lặp lại) để gây chú ý — dùng cho cả badge giỏ hàng và badge
/// chuông thông báo khi có tin chưa đọc. Cần @State riêng để driver animation lặp vô hạn nên tách
/// thành view con thay vì để trong tabBadge/notificationBell.
private struct PulsingBadge: View {
    let text: String
    @State private var animate = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.red))
            .scaleEffect(animate ? 1.22 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}
