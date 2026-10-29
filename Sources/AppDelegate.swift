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
        // Không xin quyền lúc mới mở app nữa (30/10/2026 — khách chưa biết app để làm gì, hay từ chối); xin sau khi đặt
        // đơn thành công (QuyenThongBao.xinSauKhiDatDon). Đã cho phép từ trước thì vẫn đăng ký nhận push như cũ.
        QuyenThongBao.dangKyNeuDaChoPhep()
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

/// Xin quyền thông báo ĐÚNG LÚC (30/10/2026): sau khi khách đặt đơn thành công, giải thích trước rồi mới hiện hộp xin
/// quyền của hệ thống (hộp này chỉ hiện được 1 lần trong đời app). "Để sau" thì 7 ngày sau (đơn kế tiếp) mới hỏi lại.
enum QuyenThongBao {
    private static let khoaLanHoi = "push.lanHoiQuyen"
    private static let cachHoiLai: TimeInterval = 7 * 24 * 3600

    static func dangKyNeuDaChoPhep() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let daChoPhep: [UNAuthorizationStatus] = [.authorized, .provisional, .ephemeral]
            guard daChoPhep.contains(s.authorizationStatus) else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    static func xinSauKhiDatDon() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            guard s.authorizationStatus == .notDetermined else { return }
            let lanTruoc = UserDefaults.standard.double(forKey: khoaLanHoi)
            guard Date().timeIntervalSince1970 - lanTruoc >= cachHoiLai else { return }
            // Chờ màn chuyển xong (sang Thanh toán/Đơn hàng) rồi mới hỏi.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let top = manHinhTrenCung(), !(top is UIAlertController) else { return }
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: khoaLanHoi)
                let a = UIAlertController(title: "Bật thông báo?",
                                          message: "Để biết khi nào đơn đang được giao và khi nhận Xu thưởng.",
                                          preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "Để sau", style: .cancel))
                a.addAction(UIAlertAction(title: "Bật thông báo", style: .default) { _ in
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                        guard ok else { return }
                        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
                    }
                })
                top.present(a, animated: true)
            }
        }
    }

    private static func manHinhTrenCung() -> UIViewController? {
        let goc = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }
            .first?.rootViewController
        var top = goc
        while let p = top?.presentedViewController { top = p }
        return top
    }
}
