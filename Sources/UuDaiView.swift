import SwiftUI
import UIKit

/// Port từ UuDaiScreen.tsx — thẻ tem, giới thiệu bạn bè, vòng quay may mắn. Ngày sinh (khai báo +
/// nhận quà sinh nhật) đã chuyển sang SettingsView (mục "Thông tin cá nhân", tab Tài khoản) — đây là
/// thông tin cá nhân, không phải phần thưởng, nên không thuộc tab Ưu đãi.
struct UuDaiView: View {
    var notificationBell: AnyView

    @State private var theTem: TheTem?
    @State private var gioiThieu: GioiThieuInfo?
    @State private var loading = true

    @State private var maNhap = ""
    @State private var dangApDung = false
    @State private var dangDoiTem = false
    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    @State private var alertMessage: (title: String, message: String)?
    @State private var copiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Ưu đãi", icon: "🎁", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if let theTem { theTemCard(theTem) }
                            if let gioiThieu { gioiThieuCard(gioiThieu) }
                            vongQuayCard
                        }
                        .padding(.top, 6)
                    }
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

    private func theTemCard(_ t: TheTem) -> some View {
        cardBox {
            cardHeader("🧋", "Thẻ sưu tập ly")
            Text("Mua đủ \(t.mocThuong) đơn được đổi 1 phần thưởng — báo nhân viên khi đủ điều kiện.")
                .font(.system(size: 13)).foregroundColor(Theme.textMuted)
            Text(String(repeating: "🧋", count: t.temHienTai) + String(repeating: "⚪", count: max(0, t.mocThuong - t.temHienTai)))
                .font(.system(size: 22))
            ProgressView(value: Double(t.temHienTai), total: Double(max(t.mocThuong, 1)))
                .tint(Theme.primary)
            HStack {
                Text("\(t.temHienTai)/\(t.mocThuong) tem").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                Spacer()
                Text("Đã đổi \(t.soLanDaDoiThuong) lần").font(.system(size: 12)).foregroundColor(Theme.textFaint)
            }
            if t.duDieuKienDoiThuong {
                Button {
                    Task { await doiTem() }
                } label: {
                    if dangDoiTem { ProgressView().tint(.white) } else { Text("Đổi thưởng ngay").fontWeight(.bold) }
                }
                .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
            }
        }
    }

    private func gioiThieuCard(_ g: GioiThieuInfo) -> some View {
        cardBox {
            cardHeader("👥", "Giới thiệu bạn bè")
            Text("Chia sẻ mã dưới đây — cả bạn và bạn bè đều nhận thưởng khi họ nhập mã.").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            HStack {
                Spacer()
                Text(g.maGioiThieu).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.primary).kerning(4)
                Button { UIPasteboard.general.string = g.maGioiThieu; alertMessage = ("Đã sao chép", "Mã \(g.maGioiThieu) đã được chép vào clipboard.") } label: {
                    Text("📋")
                }
                Button {
                    let av = UIActivityViewController(activityItems: ["Đặt món qua app Đenn Coffee bằng mã giới thiệu của mình \"\(g.maGioiThieu)\" là cả hai đều nhận thưởng nhé!"], applicationActivities: nil)
                    UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController?.present(av, animated: true)
                } label: {
                    Text("📤")
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
                    Button {
                        Task { await apDungMa() }
                    } label: {
                        if dangApDung { ProgressView().tint(.white) } else { Text("Áp dụng") }
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.primary)
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
            .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
        }
    }

    private func load() async {
        async let temTask = APIClient.shared.getTheTem()
        async let gtTask = APIClient.shared.getGioiThieu()
        (theTem, gioiThieu) = await (temTask, gtTask)
        loading = false
    }

    private func doiTem() async {
        dangDoiTem = true
        defer { dangDoiTem = false }
        let res = await APIClient.shared.doiTem()
        if res.isSuccess, let data = res.data {
            theTem = data
            alertMessage = ("Thành công", "Đã đổi thưởng! Báo nhân viên để nhận ly miễn phí.")
        } else {
            alertMessage = ("Chưa đủ điều kiện", res.message ?? "")
        }
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
        } else {
            alertMessage = ("Chưa quay được", res.message ?? "")
        }
    }
}
