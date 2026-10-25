import SwiftUI

/// Chính sách bảo mật nhúng thẳng bằng WKWebView (WebView.swift) thay vì Link mở Safari ngoài app —
/// giữ khách trong luồng app, khớp cách ThanhToanView nhúng trang QR có sẵn ở backend.
struct ChinhSachBaoMatView: View {
    @State private var loading = true

    var body: some View {
        ZStack {
            WebView(url: URL(string: "https://api.denncoffee.com/privacy/dat-hang.html")!) { loading = false }
            if loading { ProgressView().tint(Theme.primary) }
        }
        .navigationTitle("Chính sách bảo mật")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Thể lệ Xu — trang backend dựng ĐỘNG từ cấu hình đang chạy (gói nạp, thưởng điểm danh, tỉ lệ hộp quà,
/// xem TheLeController), nên đổi gói/tỉ lệ không phải nộp lại app. Mở từ: Bảo mật & Tài khoản, màn Nạp
/// Xu, card Hộp quà may mắn (công khai tỉ lệ trúng).
struct TheLeXuView: View {
    @State private var loading = true

    var body: some View {
        ZStack {
            WebView(url: URL(string: "https://api.denncoffee.com/the-le/xu")!) { loading = false }
            if loading { ProgressView().tint(Theme.primary) }
        }
        .navigationTitle("Thể lệ Xu")
        .navigationBarTitleDisplayMode(.inline)
    }
}
