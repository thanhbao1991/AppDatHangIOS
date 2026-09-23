import SwiftUI

/// Chính sách bảo mật nhúng thẳng bằng WKWebView (WebView.swift) thay vì Link mở Safari ngoài app —
/// giữ khách trong luồng app, khớp cách ThanhToanView nhúng trang QR có sẵn ở backend.
struct ChinhSachBaoMatView: View {
    @State private var loading = true

    var body: some View {
        ZStack {
            WebView(url: URL(string: "https://api.denncoffee.uk/privacy/dat-hang.html")!) { loading = false }
            if loading { ProgressView().tint(Theme.primary) }
        }
        .navigationTitle("Chính sách bảo mật")
        .navigationBarTitleDisplayMode(.inline)
    }
}
