import UIKit
import UserNotifications

/// Cầu nối bấm-vào-thông-báo -> mở đúng đơn: AppDelegate (UIKit, không truy cập được SwiftUI state
/// của MainTabView) set pendingHoaDonId, MainTabView.onReceive quan sát rồi tự điều hướng. Singleton
/// vì chỉ có 1 instance app-wide, không cần truyền qua environment.
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    @Published var pendingHoaDonId: String?
    private init() {}
}

/// Xin quyền + đăng ký nhận push APNs thật (thay cho Expo chưa bao giờ wire xong — xem
/// project_appdathangios_testflight_ci trong memory). deviceTokenHex lưu tạm trong RAM: nếu khách
/// CHƯA đăng nhập lúc token về (cài mới, chưa login), các hàm đăng nhập trong APIClient.swift
/// (dangNhapMatKhau/devDangNhap/xacNhanOtp) tự gửi lên ngay sau khi đăng nhập thành công.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var deviceTokenHex: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        AppDelegate.deviceTokenHex = hex
        // Chưa đăng nhập thì chưa có session để gắn token vào — gửi lại ngay sau khi đăng nhập xong.
        guard Prefs.token != nil else { return }
        Task { await APIClient.shared.registerPushToken(hex) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Best-effort — không chặn luồng chính, backend coi token null là khách chưa bật quyền.
        print("APNs: đăng ký remote notification thất bại - \(error.localizedDescription)")
    }

    // Cho phép hiện banner/sound ngay cả khi app đang mở (mặc định iOS tự nuốt im lặng nếu thiếu hàm này).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // Bấm vào thông báo (app nền/đã tắt/đang mở) -> mở thẳng chi tiết đơn, xem MainTabView.onReceive.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let hoaDonId = response.notification.request.content.userInfo["hoaDonId"] as? String {
            DeepLinkRouter.shared.pendingHoaDonId = hoaDonId
        }
        completionHandler()
    }
}
