import SwiftUI

/// Port từ UuDaiScreen.tsx — vòng quay may mắn. Ngày sinh (khai báo + nhận quà sinh nhật) đã chuyển
/// sang SettingsView (mục "Thông tin cá nhân", tab Tài khoản) — đây là thông tin cá nhân, không phải
/// phần thưởng, nên không thuộc tab Ưu đãi. Thẻ sưu tập ly VÀ giới thiệu bạn bè đã XOÁ HẲN 2026-09-23
/// (backend không còn endpoint the-tem/gioi-thieu nữa — yêu cầu "app đơn giản thôi").
struct UuDaiView: View {
    var notificationBell: AnyView

    @State private var loading = true

    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    // -1 = chưa tải xong/lỗi (ẩn dòng chữ), >=0 = số lượt thật. Cập nhật lại NGAY sau mỗi lần quay
    // từ VongQuayResult.soLuotConLai (server trả kèm), không cần gọi thêm request.
    @State private var soLuotConLai = -1
    @State private var alertMessage: (title: String, message: String)?

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Ưu đãi", icon: "gift", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    fullScreenLoading()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            vongQuayCard
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
        }
    }

    private func load() async {
        let quay = await APIClient.shared.getVongQuayInfo()
        soLuotConLai = quay?.soLuotConLai ?? -1
        loading = false
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
