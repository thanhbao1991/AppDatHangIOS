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

    // Lưới 2 cột thay List dọc (07/11/2026 user: "màn nạp cần gọn hơn và hấp dẫn hơn") — 6 gói vừa 1 màn.
    private let cot = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if let info {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Đồng bộ bộ khung TK (09/11/2026): tiêu đề thẻ có ô icon.
                        TKTieuDe(icon: "creditcard.fill", tieuDe: "Chọn gói nạp")
                            .padding(.horizontal, 4)
                        LazyVGrid(columns: cot, spacing: 12) {
                            ForEach(info.goi, id: \.self) { goi in
                                Button { goiChon = goi } label: { goiO(goi) }
                                    .buttonStyle(.plain)
                            }
                        }
                        VStack(spacing: 6) {
                            Text(NoiDung.napXuGhiChu)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textFaint)
                            NavigationLink { TheLeXuView() } label: {
                                Text("Thể lệ Xu").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
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

    /// Ô gói tối giản (07/11/2026 user: "màn đơn giản, ít thông tin nhưng hấp dẫn"): chỉ số tiền + viên vàng
    /// "+N Xu". Lần nạp đầu: backend đã trả soXuTang nhân đôi và viên vàng NHẤP NHÁY để thể hiện x2 (user 2026-11-07, thay
    /// banner chữ); từ lần sau backend trả giá trị gốc và viên vàng đứng yên.
    private func goiO(_ goi: GoiNapXu) -> some View {
        VStack(spacing: 10) {
            Text(formatTien(goi.soTien))
                .font(.system(size: 20, weight: .heavy))
                .lineLimit(1).minimumScaleFactor(0.7)
            chipXu(goi)
        }
        .padding(.vertical, 18).padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: TK.bo, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func chipXu(_ goi: GoiNapXu) -> some View {
        let chip = Text("+\(formatXu(goi.soXuTang))")
            .font(.system(size: 13, weight: .heavy))
            .foregroundColor(Theme.xuTangChu)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Theme.xuTangNen))
            .overlay(Capsule().stroke(Theme.xuTangVien, lineWidth: 1))
        if info?.lanDau == true {
            // Nhấp nháy theo thời gian (TimelineView) — mọi viên nháy đồng bộ, không bị animation khác cắt giữa chừng.
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let p = (sin(tl.date.timeIntervalSinceReferenceDate * 2 * .pi * 1.1) + 1) / 2
                chip
                    .opacity(0.55 + 0.45 * p)
                    .scaleEffect(1 + 0.06 * p)
                    .shadow(color: Color.orange.opacity(0.55 * p), radius: 7)
            }
        } else {
            chip
        }
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

/// Lần nạp đang chờ tiền về (11/11/2026): khách mở QR rồi thoát ra trước khi tiền về thì tab Tài khoản vẫn tự dò số dư
/// tới khi đủ (SettingsView.choTienNapVe), khỏi phải kéo làm mới. Chỉ giữ trong RAM, quá 30 phút thì thôi dò.
enum NapXuChoTien {
    struct Cho { let mocSoDu: Double; let tongXu: Double; let luc: Date }
    private static var cho: Cho?

    static var hienTai: Cho? {
        guard let cho, Date().timeIntervalSince(cho.luc) < 30 * 60 else { return nil }
        return cho
    }
    static func batDau(mocSoDu: Double, tongXu: Double) { cho = Cho(mocSoDu: mocSoDu, tongXu: tongXu, luc: Date()) }
    static func xong() { cho = nil }
    static func daVe(_ soDu: Double) -> Bool {
        guard let c = hienTai else { return false }
        return soDu - c.mocSoDu >= c.tongXu - 0.5
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
            .padding(.vertical, 20).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .tkThe(dem: 0)
            .tkManHinh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
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
            .padding(.top, 30)
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
        // Mở lại QR cùng lần chờ thì giữ mốc cũ (không thì tiền về giữa 2 lần mở sẽ bị coi là mốc mới).
        soDuBanDau = NapXuChoTien.hienTai.flatMap { $0.tongXu == goi.tongXuNhan ? $0.mocSoDu : nil }
        if soDuBanDau == nil, let s = await APIClient.shared.getVi()?.soDu {
            soDuBanDau = s
            NapXuChoTien.batDau(mocSoDu: s, tongXu: goi.tongXuNhan)
        }
        while !Task.isCancelled && !daNhan {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let hienTai = await APIClient.shared.getVi()?.soDu else { continue }
            guard let batDau = soDuBanDau else {
                soDuBanDau = hienTai
                NapXuChoTien.batDau(mocSoDu: hienTai, tongXu: goi.tongXuNhan)
                continue
            }
            if hienTai - batDau >= goi.tongXuNhan - 0.5 {
                daNhan = true
                NapXuChoTien.xong()
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
