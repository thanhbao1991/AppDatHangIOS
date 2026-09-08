import SwiftUI

/// Port từ MainTabs.tsx — 4 tab (Thực đơn/Đơn của tôi/Thông báo/Cài đặt), mỗi tab giữ path riêng
/// (xem Navigation.swift) thay cho react-navigation stack.
private let thongBaoPollInterval: TimeInterval = 60

struct MainTabView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var cart = CartStore()

    @State private var selectedTab: AppTab = .home
    @State private var homePath: [HomeRoute] = []
    @State private var cartPath: [HomeRoute] = []
    @State private var donHangPath: [DonHangRoute] = []
    @State private var settingsPath: [SettingsRoute] = []
    @State private var unreadCount = 0
    @State private var pollTask: Task<Void, Never>?

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
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                MenuView(path: $homePath, selectedTab: $selectedTab)
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .lyBiMat: LyBiMatView(path: $homePath)
                        case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; homePath = [] }
                        }
                    }
            }
            .tabItem { Label("Thực đơn", systemImage: icon("cup.and.saucer", .home)) }
            .tag(AppTab.home)

            NavigationStack(path: $cartPath) {
                CheckoutView(path: $cartPath)
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .lyBiMat: LyBiMatView(path: $cartPath)
                        case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; cartPath = [] }
                        }
                    }
            }
            .tabItem { Label("Giỏ hàng", systemImage: icon("cart", .cart)) }
            .badge(cartBadgeText)
            .tag(AppTab.cart)

            NavigationStack(path: $donHangPath) {
                OrderStatusView(path: $donHangPath)
                    .navigationDestination(for: DonHangRoute.self) { route in
                        switch route {
                        case .detail(let order):
                            OrderDetailView(donHangPath: $donHangPath, selectedTab: $selectedTab, cartPath: $cartPath, order: order)
                        case .thanhToan(let hoaDonId):
                            ThanhToanView(hoaDonId: hoaDonId) { donHangPath = [] }
                        }
                    }
            }
            .tabItem { Label("Đơn của tôi", systemImage: icon("list.bullet.rectangle", .donHang)) }
            .tag(AppTab.donHang)

            NavigationStack {
                ThongBaoView(selectedTab: $selectedTab)
            }
            .tabItem { Label("Thông báo", systemImage: icon("bell", .thongBao)) }
            .badge(unreadCount)
            .tag(AppTab.thongBao)

            NavigationStack(path: $settingsPath) {
                SettingsView(path: $settingsPath, isLoggedIn: $isLoggedIn)
            }
            .tabItem { Label("Cài đặt", systemImage: icon("gearshape", .settings)) }
            .tag(AppTab.settings)
        }
        .tint(Theme.primary)
        .environmentObject(cart)
        .onChange(of: selectedTab) { tab in
            if tab == .thongBao { unreadCount = 0 }
        }
        .task {
            await checkUnread()
            startPolling()
        }
        .onDisappear { pollTask?.cancel() }
    }

    private func checkUnread() async {
        let items = await APIClient.shared.getThongBao()
        guard !items.isEmpty else { return }
        let lastSeen = UserDefaults.standard.string(forKey: "thongBaoLastSeen")
        unreadCount = lastSeen.map { seen in items.filter { $0.ngayTao > seen }.count } ?? items.count
    }

    /// SF Symbol .fill khi tab đang chọn, outline khi không — khớp cảm giác native TabView
    /// thay vì hardcode 1 kiểu icon cho mọi trạng thái.
    private func icon(_ base: String, _ tab: AppTab) -> String {
        selectedTab == tab ? "\(base).fill" : base
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(thongBaoPollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await checkUnread()
            }
        }
    }
}
