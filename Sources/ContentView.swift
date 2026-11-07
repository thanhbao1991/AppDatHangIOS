import SwiftUI

/// Giai đoạn 0 (khung dự án): route đăng nhập/đã đăng nhập đã nối APIClient thật, nhưng UI hai bên
/// vẫn là placeholder — LoginView/MainTabView thật sẽ thay vào ở Giai đoạn 1-5 (xem project memory
/// nếu tìm bối cảnh: kế hoạch chuyển AppDatHangIOS từ React Native sang native SwiftUI).
struct ContentView: View {
    @State private var isLoggedIn = Prefs.isLoggedIn
    @State private var batBuocCapNhat: AppVersionPolicy?
    @State private var seasonalSplash: SeasonalTheme?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Apple 5.1.1(v): khách chưa đăng nhập vẫn xem được thực đơn/giỏ hàng — chỉ bắt đăng nhập ở
        // tính năng gắn với tài khoản (đặt hàng, đơn hàng, voucher, ưu đãi, tài khoản), xem MainTabView.
        MainTabView(isLoggedIn: $isLoggedIn)
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            isLoggedIn = false
        }
        // Cổng chặn phiên bản tối thiểu, xem VersionGate.swift. Phủ lên TRÊN cùng, không đóng được.
        .overlay {
            if let policy = batBuocCapNhat { ForceUpdateView(policy: policy) }
        }
        // Màn thoáng qua dịp lễ (kiểu banner sale Shopee) — chỉ lúc mở app (cold launch), không lặp lại
        // mỗi lần quay lại từ nền (xem onChange scenePhase bên dưới, không gọi hàm này). 1 lần/ngày/dịp,
        // xem SeasonalEvent.canHienSplash. zIndex cao hơn ForceUpdateView phòng cả 2 cùng true lúc khởi
        // động (hiếm, nhưng không nên để splash kẹt dưới cổng chặn không đóng được).
        .overlay {
            if let theme = seasonalSplash {
                SeasonalSplashView(theme: theme) {
                    SeasonalEvent.danhDauDaHienSplash()
                    seasonalSplash = nil
                }
                .zIndex(10)
            }
        }
        .task { await kiemTraPhienBan() }
        .task { await NoiDung.taiLai() }
        .task { await kiemTraQua() }
        .task {
            await SeasonalEvent.load()
            if SeasonalEvent.canHienSplash() { seasonalSplash = SeasonalEvent.active }
        }
        #if DEV_LOGIN
        .onReceive(NotificationCenter.default.publisher(for: .xemTruocSplash)) { _ in
            // Xem trước: tải ảnh dịp (nếu chưa có) rồi mới mở màn chào.
            Task {
                if let t = SeasonalEvent.active { await ManChaoCache.taiNeuCan(ma: t.maDaiDien, duongDan: nil) }
                seasonalSplash = SeasonalEvent.active
            }
        }
        #endif
        .onChange(of: scenePhase) { phase in
            // SeasonalEvent.load: iOS chỉ cho đổi icon khi app đang mở → kiểm mỗi lần quay lại app.
            if phase == .active { Task { await kiemTraPhienBan(); await kiemTraQua(); await SeasonalEvent.load() } }
        }
        .onChange(of: isLoggedIn) { v in
            if v { Task { await kiemTraQua() } }
        }
        // Màn chúc mừng quà đầu tháng — ở cấp toàn app (06/11/2026): trước đây chỉ MenuView kiểm, khách hay mở
        // thẳng tab Đơn hàng bấm "Đặt lại" (app còn sống nền) nên không bao giờ thấy màn "Nhận ngay" → lỡ quà.
        .fullScreenCover(item: $chucMung) { q in
            ChucMungHangView(qua: q) {
                _ = await ChucMungHang.nhan(q)
                chucMung = nil
                // Quà kế tiếp (hạng xong tới Top) — đợi màn cũ đóng hẳn rồi mới mở
                if !quaConLai.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    chucMung = quaConLai.removeFirst()
                }
            }
            .id(q.id) // mỗi quà 1 màn mới — không mang trạng thái "đang nhận" của màn trước
        }
    }

    @State private var chucMung: QuaChucMung?
    @State private var quaConLai: [QuaChucMung] = []

    /// Gọi lúc mở app, mỗi lần quay lại từ nền và khi vừa đăng nhập. Đang hiện màn quà thì thôi.
    private func kiemTraQua() async {
        guard isLoggedIn, chucMung == nil, batBuocCapNhat == nil else { return }
        guard let vi = await APIClient.shared.getVi() else { return }
        guard chucMung == nil else { return }
        quaConLai = ChucMungHang.quaCho(vi)
        if !quaConLai.isEmpty { chucMung = quaConLai.removeFirst() }
    }

    /// Lỗi mạng/server → fetchPolicy trả nil → giữ nguyên trạng thái hiện tại (fail-open).
    private func kiemTraPhienBan() async {
        guard let policy = await VersionGate.fetchPolicy() else { return }
        batBuocCapNhat = VersionGate.isOutdated(current: VersionGate.currentVersion, minimum: policy.toiThieu) ? policy : nil
    }
}
