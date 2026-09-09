import SwiftUI

/// Port từ MainTabs.tsx — 4 tab (Thực đơn/Đơn của tôi/Thông báo/Cài đặt) + Giỏ hàng (thêm sau).
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
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack(path: $homePath) {
                        MenuView(path: $homePath, selectedTab: $selectedTab)
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .lyBiMat: LyBiMatView(path: $homePath)
                                case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; homePath = [] }
                                }
                            }
                    }
                case .cart:
                    NavigationStack(path: $cartPath) {
                        CheckoutView(path: $cartPath)
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .lyBiMat: LyBiMatView(path: $cartPath)
                                case .thanhToan(let hoaDonId): ThanhToanView(hoaDonId: hoaDonId) { selectedTab = .donHang; cartPath = [] }
                                }
                            }
                    }
                case .donHang:
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
                case .thongBao:
                    NavigationStack {
                        ThongBaoView(selectedTab: $selectedTab)
                    }
                case .settings:
                    NavigationStack(path: $settingsPath) {
                        SettingsView(path: $settingsPath, isLoggedIn: $isLoggedIn)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            tabBar
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, label: "Thực đơn", icon: "cup.and.saucer")
            tabButton(.cart, label: "Giỏ hàng", icon: "cart", badgeText: cartBadgeText)
            tabButton(.donHang, label: "Đơn của tôi", icon: "list.bullet.rectangle")
            tabButton(.thongBao, label: "Thông báo", icon: "bell", badgeCount: unreadCount)
            tabButton(.settings, label: "Cài đặt", icon: "gearshape")
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(.bar)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, label: String, icon: String, badgeText: String? = nil, badgeCount: Int = 0) -> some View {
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
                PulsingCartBadge(text: text)
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

/// Badge giỏ hàng nhấp nháy (phóng to/thu nhỏ lặp lại) để gây chú ý khi có món trong giỏ — cần
/// @State riêng để driver animation lặp vô hạn nên tách thành view con thay vì để trong tabBadge.
private struct PulsingCartBadge: View {
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
