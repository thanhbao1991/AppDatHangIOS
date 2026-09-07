import SwiftUI

/// Giai đoạn 0 (khung dự án): route đăng nhập/đã đăng nhập đã nối APIClient thật, nhưng UI hai bên
/// vẫn là placeholder — LoginView/MainTabView thật sẽ thay vào ở Giai đoạn 1-5 (xem project memory
/// nếu tìm bối cảnh: kế hoạch chuyển AppDatHangIOS từ React Native sang native SwiftUI).
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn

    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(isLoggedIn: $isLoggedIn)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
    }
}
