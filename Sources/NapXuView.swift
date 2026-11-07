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

    // Lưới 2 cột thay List dọc (07/11/2026 user: "màn nạp cần gọn hơn và hấp dẫn hơn") — 6 gói vừa 1 màn,
    // số Xu TẶNG là chữ nổi nhất mỗi ô (thứ khách quan tâm), số tiền nạp đứng trên.
    private let cot = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if let info {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if info.lanDau == true { bannerLanDau }
                        LazyVGrid(columns: cot, spacing: 12) {
                            ForEach(info.goi, id: \.self) { goi in
                                Button { goiChon = goi } label: { goiO(goi) }
                                    .buttonStyle(.plain)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NoiDung.napXuGhiChu)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textFaint)
                            NavigationLink { TheLeXuView() } label: {
                                Text("Xem thể lệ Xu").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                }
                .background(Theme.bg.ignoresSafeArea())
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

    /// Banner nền màu chủ đạo — câu chữ từ server (NoiDungApp napLanDau*).
    private var bannerLanDau: some View {
        HStack(spacing: 12) {
            Text("🎁").font(.system(size: 34))
            VStack(alignment: .leading, spacing: 3) {
                Text(NoiDung.text("napLanDauTieuDe")).font(.system(size: 16, weight: .heavy))
                Text(NoiDung.text("napLanDauMoTa")).font(.system(size: 12)).opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.primaryGradient))
    }

    /// Gói 100k gắn "Phổ biến" — gói vừa túi đa số khách (chi ~240k/tháng), kéo khách khỏi gói 50k.
    private func laPhoBien(_ goi: GoiNapXu) -> Bool { goi.soTien == 100_000 }

    private func goiO(_ goi: GoiNapXu) -> some View {
        // Backend trả soXuTang ĐÃ nhân đôi khi lanDau → số gốc = /2 (gạch ngang cho thấy được nhân đôi).
        VStack(alignment: .leading, spacing: 6) {
            Text(formatTien(goi.soTien))
                .font(.system(size: 19, weight: .heavy))
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Text("🎁").font(.system(size: 13))
                Text("+\(formatXu(goi.soXuTang))")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Color(red: 0.85, green: 0.45, blue: 0))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            if lanDau {
                HStack(spacing: 5) {
                    Text(formatXu(goi.soXuTang / 2)).strikethrough().foregroundColor(Theme.textFaint)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    NhapNhayNhanDoi()
                }
                .font(.system(size: 11, weight: .semibold))
            }
            Text("Nhận \(formatXu(goi.tongXuNhan))")
                .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .padding(.top, laPhoBien(goi) ? 6 : 0)
        .frame(maxWidth: .infinity, minHeight: lanDau ? 118 : 100, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(laPhoBien(goi) ? Theme.primary : Theme.divider, lineWidth: laPhoBien(goi) ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if laPhoBien(goi) {
                Text("Phổ biến")
                    .font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.primary))
                    .padding(6)
            }
        }
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

/// Chip "Nhân đôi" nhấp nháy khi khách nạp lần đầu. Không dùng "x2" (07/11/2026): "x2" đứng riêng dễ bị đọc
/// là "chỉ được tặng 2 lần".
private struct NhapNhayNhanDoi: View {
    @State private var sang = true

    var body: some View {
        Text("Nhân đôi")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color(red: 1, green: 0.84, blue: 0.2)))
            .opacity(sang ? 1 : 0.35)
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
        NhacGiuNoiDungCk()

        Text(formatTien(goi.soTien)).font(.system(size: 32, weight: .bold))
        Text("Nhận \(formatXu(goi.tongXuNhan)) (tặng \(formatXu(goi.soXuTang)))")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.success)

        Text(NoiDung.text("napXuGiuNoiDung").replacingOccurrences(of: "{noiDung}", with: noiDung))
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
