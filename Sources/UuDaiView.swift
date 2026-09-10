import SwiftUI
import UIKit

/// Port từ UuDaiScreen.tsx — thẻ tem, giới thiệu bạn bè, sinh nhật, vòng quay may mắn.
struct UuDaiView: View {
    @State private var theTem: TheTem?
    @State private var gioiThieu: GioiThieuInfo?
    @State private var sinhNhat: SinhNhatInfo?
    @State private var loading = true

    @State private var maNhap = ""
    @State private var dangApDung = false
    @State private var dobDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var dobChosen = false
    @State private var dangLuuSinhNhat = false
    @State private var dangDoiTem = false
    @State private var dangQuay = false
    @State private var ketQuaQuay: String?
    @State private var alertMessage: (title: String, message: String)?
    @State private var copiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Săn thưởng")

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let theTem { theTemCard(theTem) }
                            if let gioiThieu { gioiThieuCard(gioiThieu) }
                            if let sinhNhat { sinhNhatCard(sinhNhat) }
                            vongQuayCard
                        }
                        .padding()
                    }
                }
            }
        }
        .task { await load() }
        .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(alertMessage?.message ?? "")
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider))
    }

    private func theTemCard(_ t: TheTem) -> some View {
        card {
            Text("🧋 Thẻ sưu tập ly").font(.system(size: 16, weight: .bold))
            Text("Mua đủ \(t.mocThuong) đơn được đổi 1 phần thưởng — báo nhân viên khi đủ điều kiện.")
                .font(.system(size: 13)).foregroundColor(Theme.textMuted)
            Text(String(repeating: "🧋", count: t.temHienTai) + String(repeating: "⚪", count: max(0, t.mocThuong - t.temHienTai)))
                .font(.system(size: 22))
            Text("\(t.temHienTai)/\(t.mocThuong) — đã đổi \(t.soLanDaDoiThuong) lần").font(.system(size: 12)).foregroundColor(Theme.textMuted)
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
        card {
            Text("👥 Giới thiệu bạn bè").font(.system(size: 16, weight: .bold))
            Text("Chia sẻ mã dưới đây — cả bạn và bạn bè đều nhận thưởng khi họ nhập mã.").font(.system(size: 13)).foregroundColor(Theme.textMuted)
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

    private func sinhNhatCard(_ s: SinhNhatInfo) -> some View {
        card {
            Text("🎂 Sinh nhật").font(.system(size: 16, weight: .bold))
            if let ngaySinh = s.ngaySinh {
                Text("Ngày sinh: \(formatDateVN(ngaySinh))").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                if s.dangTrongThangSinhNhat && !s.daNhanQuaNamNay {
                    Button("🎁 Nhận quà sinh nhật") { Task { await nhanQua() } }
                        .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
                }
                if s.daNhanQuaNamNay {
                    Text("Đã nhận quà năm nay rồi, hẹn năm sau nhé!").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            } else {
                Text("Nhập ngày sinh để nhận quà mừng sinh nhật mỗi năm.").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                HStack {
                    DatePicker("", selection: $dobDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: dobDate) { _ in dobChosen = true }
                    Button {
                        Task { await luuSinhNhat() }
                    } label: {
                        if dangLuuSinhNhat { ProgressView().tint(.white) } else { Text("Lưu") }
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.primary).disabled(dangLuuSinhNhat || !dobChosen)
                }
            }
        }
    }

    private var vongQuayCard: some View {
        card {
            Text("🎡 Vòng quay may mắn").font(.system(size: 16, weight: .bold))
            Text("Mỗi ngày 1 lượt quay miễn phí — thử vận may nhận thưởng vào ví!").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            if let ketQuaQuay {
                Text(ketQuaQuay).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.primary).frame(maxWidth: .infinity, alignment: .center)
            }
            Button {
                Task { await quay() }
            } label: {
                if dangQuay { ProgressView().tint(.white) } else { Text("Quay ngay 🎲").fontWeight(.bold) }
            }
            .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
        }
    }

    private func formatDateVN(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) ?? DateFormatter.iso8601NoTZ.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "dd/MM/yyyy"
        out.locale = Locale(identifier: "vi_VN")
        return out.string(from: date)
    }

    private func load() async {
        async let temTask = APIClient.shared.getTheTem()
        async let gtTask = APIClient.shared.getGioiThieu()
        async let snTask = APIClient.shared.getSinhNhat()
        (theTem, gioiThieu, sinhNhat) = await (temTask, gtTask, snTask)
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

    private func luuSinhNhat() async {
        guard dobChosen else {
            alertMessage = ("Chưa chọn ngày", "Chọn ngày sinh trước khi lưu.")
            return
        }
        dangLuuSinhNhat = true
        defer { dangLuuSinhNhat = false }
        let iso = ISO8601DateFormatter().string(from: dobDate)
        let res = await APIClient.shared.capNhatNgaySinh(iso)
        if res.success {
            dobChosen = false
            await load()
        } else {
            alertMessage = ("Lỗi", res.message ?? "")
        }
    }

    private func nhanQua() async {
        let res = await APIClient.shared.nhanQuaSinhNhat()
        alertMessage = (res.isSuccess ? "🎂 Chúc mừng!" : "Chưa nhận được", res.message ?? "")
        if res.isSuccess { await load() }
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

private extension DateFormatter {
    static let iso8601NoTZ: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
