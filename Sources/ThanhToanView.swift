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
    @State private var errorMessage: String?
    @State private var saveMessage: String?

    var body: some View {
        VStack(spacing: 0) {
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
                        ProgressView().padding(.top, 80)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 12) {
                Text("Quét mã bằng app ngân hàng bất kỳ — chuyển khoản xong quán sẽ tự ghi nhận.")
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
                Button("Xong, xem đơn của tôi", action: onDone)
                    .buttonStyle(.gradientProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.white)
        }
        .navigationTitle("Thanh toán")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Lưu ảnh", isPresented: Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })) {
            Button("OK") { saveMessage = nil }
        } message: {
            Text(saveMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(for info: ThanhToanInfoDto) -> some View {
        let tenKhach = (info.tenKhachHangText?.isEmpty ?? true) ? "Khách lẻ" : info.tenKhachHangText!
        Text(tenKhach).font(.system(size: 15)).foregroundColor(Theme.textMuted)
        Text(formatVnd(info.amount)).font(.system(size: 32, weight: .bold))

        if let qrImage {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .frame(width: 240, height: 240)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
        } else {
            ProgressView().frame(width: 240, height: 240)
        }

        Button("⬇️ Tải mã QR về máy") { saveQrToPhotos() }
            .buttonStyle(.gradientProminent)
            .frame(maxWidth: 320)
            .disabled(qrImage == nil)

        VStack(spacing: 8) {
            infoRow("Ngân hàng", info.bankName)
            infoRow("Số TK", info.bankAccountNo)
            infoRow("Chủ TK", info.bankAccountName)
            infoRow("Nội dung CK", info.billAddInfo)
        }
        .padding(16)
        .background(Theme.bg)
        .cornerRadius(12)
        .frame(maxWidth: 340)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(Theme.textMuted)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.system(size: 14))
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
        qrImage = await APIClient.shared.getBillQrImage(amount: data.amount, addInfo: data.billAddInfo)
            .flatMap { UIImage(data: $0) }
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
