#if DEV_LOGIN
import SwiftUI

/// Bản dev (10/11/2026 chủ quán: "tất cả button thử nghiệm gom vào đây, hiển thị trên tất cả tab"): menu ⚡ cạnh chuông ở
/// MỌI tab (gắn trong MainTabView.notificationBell). Trạng thái xem thử để chung ở đây cho các màn đọc.
@MainActor
final class DevXemThu: ObservableObject {
    static let shared = DevXemThu()

    /// Tab Tài khoản: thẻ Xu như ngày 1 tháng sau + chuỗi màn chúc mừng.
    @Published var xemTruocNgay1 = false
    /// Tab Ưu đãi: ngày đang thử điểm danh (0 = tắt) — ô ngày tick tới ngày này.
    @Published var thuNgay = 0
    /// Hiệu ứng điểm danh đang chờ hiện (ngày) — UuDaiView nhận rồi đặt về nil.
    @Published var hieuUngDiemDanh: Int?
    /// Lệnh "xem thử hiệu ứng mở quà" — UuDaiView nhận rồi đặt về false.
    @Published var moQua = false
    /// Chỉ để nhãn "Xem trước dịp lễ" vẽ lại (SeasonalEvent.previewOverride là static var).
    @Published var tickDipLe = 0

    /// Bấm xoay vòng qua từng dịp rồi về "tắt".
    func xoayDipLe() {
        if let current = SeasonalEvent.previewOverride,
           let idx = SeasonalTheme.allCases.firstIndex(of: current),
           idx + 1 < SeasonalTheme.allCases.count {
            SeasonalEvent.previewOverride = SeasonalTheme.allCases[idx + 1]
        } else if SeasonalEvent.previewOverride == nil {
            SeasonalEvent.previewOverride = SeasonalTheme.allCases.first
        } else {
            SeasonalEvent.previewOverride = nil
        }
        Theme.applyNavBarAppearance()
        SeasonalEvent.capNhatIcon()
        tickDipLe += 1
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
        Task {
            await SeasonalEvent.taiXemTruoc()
            if SeasonalEvent.previewOverride != nil {
                NotificationCenter.default.post(name: .xemTruocSplash, object: nil)
            }
        }
    }

    /// Bấm lần lượt ngày 1 → 7, sau ngày 7 thì tắt.
    func buocDiemDanh() {
        if thuNgay >= 7 { thuNgay = 0; return }
        thuNgay += 1
        hieuUngDiemDanh = thuNgay
    }
}

/// Icon ⚡ — menu các nút thử nghiệm. `moTab` chuyển sang tab cần thiết để thấy hiệu ứng.
struct DevMenuButton: View {
    @ObservedObject private var x = DevXemThu.shared
    var moTab: (AppTab) -> Void

    private var dangThu: Bool { x.xemTruocNgay1 || x.thuNgay > 0 || SeasonalEvent.previewOverride != nil }

    var body: some View {
        let _ = x.tickDipLe
        Menu {
            Button(x.xemTruocNgay1 ? "🧪 Tắt xem trước ngày 1" : "🧪 Xem trước ngày 1 tháng sau") {
                x.xemTruocNgay1.toggle()
                if x.xemTruocNgay1 { moTab(.settings) }
            }
            Button(SeasonalEvent.previewOverride.map { "🧪 Đang xem: \($0.previewTen) (bấm để đổi/tắt)" } ?? "🧪 Xem trước dịp lễ") {
                x.xoayDipLe()
            }
            Button("🧪 Xem trước chúc mừng sinh nhật") {
                NotificationCenter.default.post(name: .xemTruocSinhNhat, object: nil)
            }
            Button(x.thuNgay == 0 ? "🧪 Thử điểm danh: ngày 1" : x.thuNgay < 7 ? "🧪 Thử điểm danh: ngày \(x.thuNgay + 1)" : "🧪 Tắt thử điểm danh") {
                x.buocDiemDanh()
                if x.thuNgay > 0 { moTab(.sanThuong) }
            }
            Button("🧪 Xem thử hiệu ứng mở quà") {
                moTab(.sanThuong)
                x.moQua = true
            }
        } label: {
            Image(systemName: dangThu ? "bolt.fill" : "bolt")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
        }
        // Chữ mục menu theo màu chủ đạo — header bọc .tint(.white) sẽ làm chữ trắng vô hình.
        .tint(Theme.primary)
        .accessibilityLabel("Xem trước")
    }
}
#endif
