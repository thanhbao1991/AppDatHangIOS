import SwiftUI
import UIKit
import Photos

/// Thay hẳn WebView nhúng trang HTML backend (lag, xem incident cũ) — tự vẽ QR native bằng
/// SwiftUI, giống cách AppQuanLyIOS làm: chỉ xin ẢNH PNG đã vẽ sẵn qua /api/HoaDon/bill-qr (cùng
/// BankQrConfig, không tự build VietQR payload ở Swift). Amount/addInfo/STK/tên TK LUÔN lấy từ
/// ThanhToanInfoDto mỗi lần mở màn hình — đổi STK ở backend là app tự cập nhật, không cần build
/// lại app. Bỏ nút "Chuyển khoản qua X" (deep link dl.vietqr.io) — độ tin cậy phụ thuộc app ngân
/// hàng có support hay không, ngoài tầm kiểm soát của mình (xem thảo luận session). Thay bằng nút
/// tải ảnh QR về máy — khách tự mở app ngân hàng bất kỳ rồi quét từ Ảnh, luôn hoạt động vì QR tự
/// chứa đủ thông tin (không phụ thuộc integration riêng như Zalo Pay).
struct ThanhToanView: View {
    let hoaDonId: String
    let onDone: () -> Void

    @State private var info: ThanhToanInfoDto?
    @State private var qrImage: UIImage?
    @State private var qrFailed = false
    @State private var errorMessage: String?
    @State private var saveMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let info {
                    content(for: info)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundColor(Theme.danger)
                            .multilineTextAlignment(.center)
                        Button("Thử lại") { Task { await load() } }
                            .buttonStyle(.gradientProminent)
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.3)
                        Text("Đang tải thông tin thanh toán...")
                            .font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    }
                    .padding(.top, 100)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("Thanh toán")
        .navigationBarTitleDisplayMode(.inline)
        // Bỏ nút back hệ thống (feedback 2026-09-28) — back sẽ pop về CheckoutView (giỏ đã clear(),
        // hiện trống, trải nghiệm tệ). Chỉ còn đúng 1 lối ra: nút "Xong, xem đơn hàng" gọi onDone()
        // để về đúng tab Đơn hàng.
        .navigationBarBackButtonHidden(true)
        .task { await load() }
        // .tint(.black) khớp quyết định sẵn có ở AppDatHangIOSApp.init (UIAlertController ép
        // tintColor đen thuần) — tránh nút trắng vô hình nếu tint trắng nào đó kế thừa xuống đây.
        .alert("Lưu ảnh", isPresented: Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })) {
            Button("OK") { saveMessage = nil }
                .tint(.black)
        } message: {
            Text(saveMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(for info: ThanhToanInfoDto) -> some View {
        // Bỏ hiện tên khách (feedback 2026-09-28) — thay bằng lời cảm ơn 2 dòng, không cần đọc
        // tenKhachHangText nữa.
        VStack(spacing: 2) {
            Text("Quán nhỏ cảm ơn to").font(.system(size: 15, weight: .semibold))
            Text("Cảm ơn bạn đã tin yêu quán!").font(.system(size: 13))
        }
        .foregroundColor(Theme.textMuted)
        .multilineTextAlignment(.center)

        // Đổi bố cục (feedback 2026-09-28): thêm câu mời NGAY TRÊN mã QR, số tiền chuyển XUỐNG DƯỚI
        // mã QR (trước đây số tiền nằm trên, ngay dưới lời cảm ơn).
        Text("Mời bạn quét mã QR").font(.system(size: 15, weight: .medium)).foregroundColor(Theme.textMuted)

        Group {
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 240, height: 240)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
            } else if qrFailed {
                VStack(spacing: 10) {
                    Text("Không tải được ảnh QR, mạng có thể đang chậm.")
                        .font(.system(size: 13)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
                    Button("Thử tải lại") { Task { await loadQr(for: info) } }
                        .buttonStyle(.gradientProminent)
                }
                .frame(width: 240, height: 240)
                .padding(12)
                .background(Theme.bg)
                .cornerRadius(12)
            } else {
                ProgressView().frame(width: 240, height: 240)
            }
        }

        Text(formatVnd(info.amount)).font(.system(size: 32, weight: .bold))

        Button("⬇️ Tải mã QR về máy") { saveQrToPhotos() }
            .buttonStyle(.gradientProminent)
            .frame(maxWidth: 320)
            .disabled(qrImage == nil)

        // "onDone" từng bị KHAI BÁO nhưng KHÔNG NƠI NÀO GỌI (bug thật, phát hiện 2026-09-28) — khách
        // xem/lưu QR xong chỉ có nút back hệ thống, pop về đúng route TRƯỚC route .thanhToan trên
        // stack (CheckoutView nếu vừa đặt hàng xong, cart đã clear() nên hiện trống — trải nghiệm tệ).
        // Bấm "Xong" gọi onDone() thật để về tab Đơn hàng (xem MainTabView: onDone luôn set
        // selectedTab=.donHang + path=[], KHÔNG bao giờ tới trang chi tiết đơn hàng).
        Button("Xong, xem đơn hàng") { onDone() }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
            .frame(maxWidth: 320)
    }

    private func formatVnd(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))") + " đ"
    }

    private func load() async {
        errorMessage = nil
        let env = await APIClient.shared.getThanhToanInfo(hoaDonId: hoaDonId)
        guard env.isSuccess, let data = env.data else {
            errorMessage = env.message ?? "Không tải được thông tin thanh toán."
            return
        }
        info = data
        await loadQr(for: data)
    }

    private func loadQr(for info: ThanhToanInfoDto) async {
        qrFailed = false
        qrImage = nil
        let data = await APIClient.shared.getBillQrImage(amount: info.amount, addInfo: info.billAddInfo)
        qrImage = data.flatMap { UIImage(data: $0) }
        qrFailed = qrImage == nil
    }

    private func saveQrToPhotos() {
        guard let qrImage else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveMessage = "Chưa có quyền lưu ảnh — vào Cài đặt > Đenn Coffee > Ảnh để cấp quyền."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: qrImage)
            }) { success, _ in
                DispatchQueue.main.async {
                    saveMessage = success ? "Đã lưu mã QR vào Ảnh." : "Lưu ảnh thất bại, vui lòng thử lại."
                }
            }
        }
    }
}
