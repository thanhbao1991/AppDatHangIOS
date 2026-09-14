import SwiftUI

@main
struct AppDatHangIOSApp: App {
    init() {
        // iOS 15+ tự thêm 1 khoảng trống phía trên header ghim (pinned) ĐẦU TIÊN của List — lỗi
        // đã biết của UITableView, thấy rõ nhất ở tab Thực đơn (header "Yêu thích" bị đẩy xuống
        // khi mới mở tab). Set 0 app-wide vì AppDatHangIOS không dùng List section header nào
        // khác cần giữ padding này.
        UITableView.appearance().sectionHeaderTopPadding = 0

        // Set nav bar 1 lần ở tầng UIKit thay vì .toolbarBackground/.toolbarColorScheme gắn theo
        // từng View (cách cũ, đã bỏ hẳn — xem git log brandNavBar() trong Theme.swift) — MainTabView
        // dùng switch selectedTab để đổi tab (không phải TabView giữ sống), nên mỗi lần rời rồi quay
        // lại 1 tab, NavigationStack của tab đó bị HUỶ VÀ TẠO LẠI với path đã có sẵn (không phải push
        // mới). Modifier gắn theo View không áp lại kịp trong tình huống này (verify thật: đổi
        // brandNavBar() vẫn KHÔNG hết lỗi) — set cứng UINavigationBar.appearance() 1 lần lúc khởi
        // động app mới thực sự hết, vì nó không phụ thuộc vòng đời của View nào cả.
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Theme.primary)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        let backItemAppearance = UIBarButtonItemAppearance()
        backItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.backButtonAppearance = backItemAppearance
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
