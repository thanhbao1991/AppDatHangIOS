import SwiftUI

/// Port từ ThanhToanScreen.tsx — nhúng thẳng trang QR đã có sẵn ở backend, không tự dựng UI QR.
struct ThanhToanView: View {
    let hoaDonId: String
    let onDone: () -> Void

    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let url = Prefs.thanhToanQrUrl(hoaDonId: hoaDonId) {
                    WebView(url: url) { loading = false }
                }
                if loading { ProgressView().tint(Theme.primary) }
            }

            VStack(spacing: 12) {
                Text("Quét mã hoặc bấm vào QR để mở app ngân hàng — chuyển khoản xong quán sẽ tự ghi nhận.")
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
                Button("Xong, xem đơn của tôi", action: onDone)
                    .buttonStyle(.borderedProminent).tint(Theme.primary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.white)
        }
        .navigationTitle("Thanh toán")
        .navigationBarTitleDisplayMode(.inline)
        .brandNavBar()
    }
}
