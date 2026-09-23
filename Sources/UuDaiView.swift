import SwiftUI
import UIKit

/// Port từ UuDaiScreen.tsx — giới thiệu bạn bè, vòng quay may mắn. Ngày sinh (khai báo + nhận quà
/// sinh nhật) đã chuyển sang SettingsView (mục "Thông tin cá nhân", tab Tài khoản) — đây là thông
/// tin cá nhân, không phải phần thưởng, nên không thuộc tab Ưu đãi. Thẻ sưu tập ly đã XOÁ HẲN
/// 2026-09-23 (backend không còn endpoint the-tem nữa).
struct UuDaiView: View {
    var notificationBell: AnyView

    @State private var gioiThieu: GioiThieuInfo?
    @State private var loading = true

    @State private var maNhap = ""
    @State private var dangApDung = false
    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    // -1 = chưa tải xong/lỗi (ẩn dòng chữ), >=0 = số lượt thật. Cập nhật lại NGAY sau mỗi lần quay
    // từ VongQuayResult.soLuotConLai (server trả kèm), không cần gọi thêm request.
    @State private var soLuotConLai = -1
    // 0-6, hiện tiến độ "X/7 ngày" — tải qua getVongQuayInfo() (chính nơi backend ghi nhận hôm nay
    // đã mở app, xem APIClient.getVongQuayInfo).
    @State private var soNgayLienTiepDangNhap = 0
    @State private var alertMessage: (title: String, message: String)?
    @State private var copiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Ưu đãi", icon: "gift", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    fullScreenLoading()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Vòng quay lên ĐẦU (yêu cầu 2026-09-23) — hành động khách làm MỖI NGÀY
                            // (1 lượt/ngày) nên đáng được thấy trước, khác giới thiệu bạn bè vốn
                            // không đổi trạng thái mỗi lần mở tab. Giới thiệu bạn bè giờ liên quan
                            // trực tiếp tới vòng quay (nhập mã cả 2 bên đều +1 lượt quay).
                            vongQuayCard
                            if let gioiThieu { gioiThieuCard(gioiThieu) }
                        }
                        .padding(.top, 6)
                    }
                    .refreshable { await load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        .task { await load() }
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    /// Header thống nhất cho mọi card — icon trong khung tròn màu nhấn + tiêu đề, thay vì emoji nằm
    /// trơn cạnh chữ (trước đây 3 card trông đều na ná nhau, khó phân biệt loại ưu đãi khi lướt nhanh).
    private func cardHeader(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(Theme.primaryTint)
                .clipShape(Circle())
            Text(title).font(.system(size: 16, weight: .bold))
            Spacer()
        }
    }

    private func gioiThieuCard(_ g: GioiThieuInfo) -> some View {
        cardBox {
            cardHeader("👥", "Giới thiệu bạn bè")
            Text("Chia sẻ mã dưới đây — cả bạn và bạn bè đều nhận thưởng + thêm 1 lượt vòng quay may mắn khi họ nhập mã.").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            HStack {
                Spacer()
                Text(g.maGioiThieu).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.primary).kerning(4)
                Button { UIPasteboard.general.string = g.maGioiThieu; alertMessage = ("Đã sao chép", "Mã \(g.maGioiThieu) đã được chép vào clipboard.") } label: {
                    Image(systemName: "doc.on.doc")
                }
                Button {
                    let av = UIActivityViewController(activityItems: ["Đặt món qua app Đenn Coffee bằng mã giới thiệu của mình \"\(g.maGioiThieu)\" là cả hai đều nhận thưởng nhé!"], applicationActivities: nil)
                    UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController?.present(av, animated: true)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Spacer()
            }
            .padding(.vertical, 10).background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Đã giới thiệu \(g.soNguoiDaGioiThieu) người").font(.system(size: 12)).foregroundColor(Theme.textFaint)

            if !g.daDuocGioiThieu {
                Text("Được bạn bè giới thiệu? Nhập mã của họ:").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                HStack {
                    TextField("Nhập mã giới thiệu", text: $maNhap)
                        .textInputAutocapitalization(.characters)
                        .textFieldStyle(.roundedBorder)
                        .tint(Theme.primary)
                    Button {
                        Task { await apDungMa() }
                    } label: {
                        if dangApDung { ProgressView().tint(.white) } else { Text("Áp dụng") }
                    }
                    .buttonStyle(.gradientProminent)
                }
            }
        }
    }

    private var vongQuayCard: some View {
        cardBox {
            cardHeader("🎡", "Vòng quay may mắn")
            Text("Mỗi ngày 1 lượt quay miễn phí — thử vận may nhận thưởng Xu!").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            if let ketQuaQuay {
                Text("🎉 " + ketQuaQuay)
                    .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(Theme.primaryTint).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button {
                Task { await quay() }
            } label: {
                if dangQuay { ProgressView().tint(.white) } else { Text("Quay ngay 🎲").fontWeight(.bold) }
            }
            .buttonStyle(.gradientProminent).frame(maxWidth: .infinity)
            // -1 = chưa tải xong (ẩn hẳn dòng chữ, tránh nháy "0 lượt" sai trước khi API trả về).
            if soLuotConLai >= 0 {
                Text("Còn \(soLuotConLai) lượt")
                    .font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Tiến độ chuỗi đăng nhập 7 ngày — 7 chấm tròn, đầy = đã tính ngày đó trong chuỗi hiện
            // tại. Đủ 7 backend tự +2 lượt rồi reset về 0, nên chấm KHÔNG BAO GIỜ đầy hết 7/7 lâu —
            // chuyển thẳng về 0/7 ngay hôm sau, đúng ý "reset chu kỳ mới".
            VStack(spacing: 6) {
                Divider()
                HStack(spacing: 6) {
                    Text("Chuỗi đăng nhập").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    Spacer()
                    Text("\(soNgayLienTiepDangNhap)/7 ngày").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                }
                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { ngay in
                        Circle()
                            .fill(ngay <= soNgayLienTiepDangNhap ? Theme.primary : Theme.textFaint.opacity(0.25))
                            .frame(width: 14, height: 14)
                    }
                }
                Text("Đủ 7 ngày liên tiếp: +2 lượt quay!").font(.system(size: 11)).foregroundColor(Theme.textFaint)
            }
            .padding(.top, 4)
        }
    }

    private func load() async {
        async let gtTask = APIClient.shared.getGioiThieu()
        async let quayTask = APIClient.shared.getVongQuayInfo()
        let (gt, quay) = await (gtTask, quayTask)
        gioiThieu = gt
        soLuotConLai = quay?.soLuotConLai ?? -1
        soNgayLienTiepDangNhap = quay?.soNgayLienTiepDangNhap ?? 0
        loading = false
    }

    private func apDungMa() async {
        guard !maNhap.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        dangApDung = true
        defer { dangApDung = false }
        let res = await APIClient.shared.apDungMaGioiThieu(maNhap.trimmingCharacters(in: .whitespaces))
        alertMessage = (res.success ? "Thành công" : "Không áp dụng được", res.message ?? "")
        if res.success {
            maNhap = ""
            await load()
        }
    }

    private func quay() async {
        dangQuay = true
        ketQuaQuay = nil
        defer { dangQuay = false }
        let res = await APIClient.shared.quayVongQuay()
        if res.isSuccess, let data = res.data {
            ketQuaQuay = data.label
            soLuotConLai = data.soLuotConLai
        } else {
            alertMessage = ("Chưa quay được", res.message ?? "")
        }
    }
}
