import SwiftUI
import UIKit
import Photos

/// Nạp Xu — mở từ card Xu ở tab Tài khoản. Chỉ có các gói cố định (backend NapXuService KHÔNG cộng Xu
/// cho số tiền lẻ), bấm 1 gói ra QR khoá sẵn số tiền + nội dung "SEVQR NAP…" của khách. Tiền về qua
/// webhook SePay, app chỉ cần tải lại số dư để thấy.
struct NapXuView: View {
    /// Nạp xong bấm "Xong" → đóng cả chuỗi Nạp Xu về tab Tài khoản (SettingsView set showNapXu = false).
    var onXong: () -> Void = {}

    @State private var info: NapXuInfoDto?
    @State private var errorMessage: String?
    @State private var goiChon: GoiNapXu?

    var body: some View {
        Group {
            if let info {
                List {
                    if info.lanDau == true {
                        Section {
                            HStack(spacing: 10) {
                                Text("🎁").font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Nạp lần đầu: nhân đôi Xu tặng").font(.system(size: 15, weight: .bold))
                                    Text("Số Xu tặng bên dưới đã gồm phần nhân đôi.")
                                        .font(.system(size: 12)).foregroundColor(Theme.textMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Section {
                        ForEach(info.goi, id: \.self) { goi in
                            Button { goiChon = goi } label: { goiRow(goi) }
                                .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("Xu dùng để thanh toán đồ uống tại quán và trên app, 1 Xu = 1đ. Xu đã nạp không quy đổi lại thành tiền mặt.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textFaint)
                    }
                }
                .listStyle(.insetGrouped)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage).foregroundColor(Theme.danger).multilineTextAlignment(.center)
                    Button("Thử lại") { Task { await load() } }.buttonStyle(.gradientProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                fullScreenLoading()
            }
        }
        .navigationTitle("Nạp Xu")
        .navigationBarTitleDisplayMode(.inline)
        .task { if info == nil { await load() } }
        .navigationDestination(isPresented: Binding(get: { goiChon != nil }, set: { if !$0 { goiChon = nil } })) {
            if let goiChon, let info {
                NapXuQrView(goi: goiChon, noiDung: info.noiDungChuyenKhoan, onXong: onXong)
            }
        }
    }

    private var lanDau: Bool { info?.lanDau == true }

    private func goiRow(_ goi: GoiNapXu) -> some View {
        HStack(spacing: 12) {
            Theme.xuIcon(40)
            VStack(alignment: .leading, spacing: 3) {
                Text(formatTien(goi.soTien)).font(.system(size: 17, weight: .bold))
                Text("Nhận \(formatXu(goi.tongXuNhan))").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            }
            Spacer()
            // Số Xu tặng thay vì %: thưởng cố định theo mốc nên % giảm dần ở gói lớn — nhìn "+3%" khách tưởng gói
            // lớn kém lời hơn. Số Xu thì tăng theo gói (24/10/2026). Lần đầu: ghi số GỐC + "x2" nhấp nháy (backend
            // trả soXuTang đã nhân đôi khi lanDau → chia 2 lấy số gốc).
            HStack(spacing: 5) {
                Text("+\(formatXu(lanDau ? goi.soXuTang / 2 : goi.soXuTang))")
                if lanDau { NhapNhayX2() }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.success))
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.textFaint)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func load() async {
        errorMessage = nil
        let env = await APIClient.shared.getNapXuInfo()
        guard env.isSuccess, let data = env.data else {
            errorMessage = env.message ?? "Không tải được các gói nạp."
            return
        }
        info = data
    }
}

/// Chữ "x2" nhấp nháy trên nhãn gói nạp khi khách nạp lần đầu.
private struct NhapNhayX2: View {
    @State private var sang = true

    var body: some View {
        Text("x2")
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(Theme.success)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.yellow))
            .opacity(sang ? 1 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { sang = false }
            }
    }
}

/// QR nạp 1 gói — bố cục giống ThanhToanView (QR backend vẽ qua /HoaDon/bill-qr, nút tải ảnh QR).
/// Dò số dư mỗi 5 giây khi đang mở màn này để báo "Đã nạp thành công" ngay khi webhook cộng Xu.
struct NapXuQrView: View {
    let goi: GoiNapXu
    let noiDung: String
    var onXong: () -> Void = {}

    @State private var qrImage: UIImage?
    @State private var qrFailed = false
    @State private var saveMessage: String?
    @State private var soDuBanDau: Double?
    @State private var daNhan = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if daNhan {
                    thanhCong
                } else {
                    qrContent
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("Nạp \(formatTien(goi.soTien))")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadQr() }
        .task { await doSoDu() }
        .popupHost { host in
            host.alert("Lưu ảnh", isPresented: Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })) {
                Button("OK") { saveMessage = nil }
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var qrContent: some View {
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
                    Button("Thử tải lại") { Task { await loadQr() } }
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

        Text(formatTien(goi.soTien)).font(.system(size: 32, weight: .bold))
        Text("Nhận \(formatXu(goi.tongXuNhan)) (tặng \(formatXu(goi.soXuTang)))")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.success)

        Text("Giữ nguyên số tiền và nội dung chuyển khoản \"\(noiDung)\" để Xu được cộng tự động.")
            .font(.system(size: 12))
            .foregroundColor(Theme.textFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)

        Button("⬇️ Tải mã QR về máy") { saveQrToPhotos() }
            .buttonStyle(.gradientProminent)
            .frame(maxWidth: 320)
            .disabled(qrImage == nil)

        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.8)
            Text("Đang chờ tiền về…").font(.system(size: 12)).foregroundColor(Theme.textMuted)
        }
    }

    @ViewBuilder
    private var thanhCong: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundColor(Theme.success)
            .padding(.top, 60)
        Text("Nạp Xu thành công").font(.system(size: 20, weight: .bold))
        Text("+\(formatXu(goi.tongXuNhan)) đã vào ví của bạn.")
            .font(.system(size: 14)).foregroundColor(Theme.textMuted)
        Button("Xong") { onXong() }
            .buttonStyle(.gradientProminent)
            .frame(maxWidth: 320)
    }

    private func loadQr() async {
        qrFailed = false
        qrImage = nil
        let data = await APIClient.shared.getBillQrImage(amount: goi.soTien, addInfo: noiDung)
        qrImage = data.flatMap { UIImage(data: $0) }
        qrFailed = qrImage == nil
    }

    /// Tự huỷ khi rời màn (task gắn view). So với số dư lúc mở: tăng đủ tổng Xu của gói = đã nạp. Lần đọc
    /// số dư đầu lỗi mạng thì vòng sau đọc lại làm mốc (không thì không bao giờ báo được thành công).
    private func doSoDu() async {
        soDuBanDau = await APIClient.shared.getVi()?.soDu
        while !Task.isCancelled && !daNhan {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let hienTai = await APIClient.shared.getVi()?.soDu else { continue }
            guard let batDau = soDuBanDau else { soDuBanDau = hienTai; continue }
            if hienTai - batDau >= goi.tongXuNhan - 0.5 {
                daNhan = true
            }
        }
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
