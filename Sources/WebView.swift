import SwiftUI
import WebKit

/// Endpoint /HoaDon/{id}/qr trả về TRANG HTML tự vẽ (QR + tên ngân hàng/STK/nội dung CK, không
/// phải ảnh thuần) — xem HoaDonController.GetBillQrByHoaDonId — nên cần WKWebView render thật,
/// khác các màn còn lại đã bỏ được react-native-webview.
struct WebView: UIViewRepresentable {
    let url: URL
    var onLoadEnd: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onLoadEnd: onLoadEnd) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoadEnd: (() -> Void)?
        init(onLoadEnd: (() -> Void)?) { self.onLoadEnd = onLoadEnd }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onLoadEnd?() }
    }
}
