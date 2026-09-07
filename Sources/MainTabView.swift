import SwiftUI

/// Port từ MainTabs.tsx — 4 tab (Thực đơn/Đơn của tôi/Thông báo/Cài đặt), mỗi tab giữ path riêng
/// (xem Navigation.swift) thay cho react-navigation stack.
private let thongBaoPollInterval: TimeInterval = 60

struct MainTabView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var cart = CartStore()

    @State private var selectedTab: AppTab = .home
    @State private var homePath: [HomeRoute] = []
    @State private var donHangPath: [DonHangRoute] = []
    @State private var settingsPath: [SettingsRoute] = []
    @State private var unreadCount = 0
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                MenuView(path: $homePath)
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .checkout: CheckoutView(path: $homePath)
                        case .lyBiMat: LyBiMatView(path: $homePath)
                        case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; homePath = [] }
                        }
                    }
            }
            .tabItem { Label("Thực đơn", systemImage: "fork.knife") }
            .tag(AppTab.home)

            NavigationStack(path: $donHangPath) {
                OrderStatusView(path: $donHangPath)
                    .navigationDestination(for: DonHangRoute.self) { route in
                        switch route {
                        case .detail(let order):
                            OrderDetailView(donHangPath: $donHangPath, selectedTab: $selectedTab, homePath: $homePath, order: order)
                        case .thanhToan(let hoaDonId):
                            ThanhToanView(hoaDonId: hoaDonId) { donHangPath = [] }
                        }
                    }
            }
            .tabItem { Label("Đơn của tôi", systemImage: "list.bullet.rectangle") }
            .tag(AppTab.donHang)

            NavigationStack {
                ThongBaoView(selectedTab: $selectedTab)
            }
            .tabItem { Label("Thông báo", systemImage: "bell") }
            .badge(unreadCount)
            .tag(AppTab.thongBao)

            NavigationStack(path: $settingsPath) {
                SettingsView(path: $settingsPath, isLoggedIn: $isLoggedIn)
            }
            .tabItem { Label("Cài đặt", systemImage: "gearshape") }
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
