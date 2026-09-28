import SwiftUI
import UIKit

// Danh sách rút gọn app ngân hàng phổ biến ở VN có trong VietQR — khớp CK_BANKS bên
// HoaDonController.GetBillQrByHoaDonId (trang HTML cũ). Đây là bảng mã CHUẨN VietQR, không phải
// cấu hình riêng của quán, nên hardcode ở đây không có rủi ro "đổi STK phải update app" — chỉ
// STK/tên TK/mã ngân hàng NHẬN tiền (info.bank*) mới luôn lấy từ API.
private let ckBanks: [(code: String, name: String)] = [
    ("icb", "VietinBank"), ("vcb", "Vietcombank"), ("tcb", "Techcombank"),
    ("mb", "MB Bank"), ("acb", "ACB"), ("bidv", "BIDV"), ("vpb", "VPBank"),
    ("tpb", "TPBank"), ("vba", "Agribank"), ("vib", "VIB"), ("shb", "SHB"), ("hdb", "HDBank"),
]

/// Thay hẳn WebView nhúng trang HTML backend (lag, xem incident cũ) — tự vẽ QR native bằng
/// SwiftUI, giống cách AppQuanLyIOS làm: chỉ xin ẢNH PNG đã vẽ sẵn qua /api/HoaDon/bill-qr (cùng
/// BankQrConfig, không tự build VietQR payload ở Swift). Amount/addInfo/STK/tên TK/mã ngân hàng
/// LUÔN lấy từ ThanhToanInfoDto mỗi lần mở màn hình — đổi STK ở backend là app tự cập nhật, không
/// cần build lại/submit App Store lại.
struct ThanhToanView: View {
    let hoaDonId: String
    let onDone: () -> Void

    @State private var info: ThanhToanInfoDto?
    @State private var qrImage: UIImage?
    @State private var errorMessage: String?
    @State private var showBankPicker = false
    @AppStorage("thanhToan_lastBankApp") private var lastBankApp = ""

    private var selectedBankCode: String {
        lastBankApp.isEmpty ? (info?.bankAppCode ?? "icb") : lastBankApp
    }

    private var selectedBankName: String {
        ckBanks.first { $0.code == selectedBankCode }?.name ?? (info?.bankName ?? "")
    }

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
                Text("Quét mã hoặc bấm vào QR để mở app ngân hàng — chuyển khoản xong quán sẽ tự ghi nhận.")
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
        .confirmationDialog("Chọn ứng dụng ngân hàng", isPresented: $showBankPicker, titleVisibility: .visible) {
            ForEach(ckBanks, id: \.code) { bank in
                Button(bank.name) { lastBankApp = bank.code; openBankApp() }
            }
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

        Button("💳 Chuyển khoản qua \(selectedBankName)") { openBankApp() }
            .buttonStyle(.gradientProminent)
            .frame(maxWidth: 320)

        Button("Đổi ứng dụng khác") { showBankPicker = true }
            .font(.system(size: 13))
            .foregroundColor(Theme.primary)

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

    private func openBankApp() {
        guard let info else { return }
        let vnd = Int(info.amount.rounded())
        var comps = URLComponents(string: "https://dl.vietqr.io/pay")!
        comps.queryItems = [
            URLQueryItem(name: "app", value: selectedBankCode),
            URLQueryItem(name: "ba", value: "\(info.bankAccountNo)@\(info.bankAppCode)"),
            URLQueryItem(name: "am", value: "\(vnd)"),
            URLQueryItem(name: "tn", value: info.billAddInfo),
            URLQueryItem(name: "bn", value: info.bankAccountName),
        ]
        if let url = comps.url {
            UIApplication.shared.open(url)
        }
    }
}
