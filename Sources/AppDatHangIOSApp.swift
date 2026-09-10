import SwiftUI

@main
struct AppDatHangIOSApp: App {
    init() {
        // iOS 15+ tự thêm 1 khoảng trống phía trên header ghim (pinned) ĐẦU TIÊN của List — lỗi
        // đã biết của UITableView, thấy rõ nhất ở tab Thực đơn (header "Yêu thích" bị đẩy xuống
        // khi mới mở tab). Set 0 app-wide vì AppDatHangIOS không dùng List section header nào
        // khác cần giữ padding này.
        UITableView.appearance().sectionHeaderTopPadding = 0
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
