import SwiftUI

/// Port từ LyBiMatScreen.tsx (blind box).
struct LyBiMatView: View {
    @Binding var path: [HomeRoute]

    @State private var diaChi = ""
    @State private var savedDiaChi: [DiaChiKhachHang] = []
    @State private var loading = false
    @State private var error = ""
    @State private var result: LyBiMatResult?
    @State private var giaLyBiMat: Double = 25_000
    @State private var clientOrderId: String?

    var body: some View {
        Group {
            if let result {
                revealView(result)
            } else {
                formView
            }
        }
        .navigationTitle("Ly Bí Mật 🎁")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let diaChiTask = APIClient.shared.getDiaChiList()
            async let giaTask = APIClient.shared.getGiaLyBiMat()
            let (list, gia) = await (diaChiTask, giaTask)
            savedDiaChi = list
            if let macDinh = list.first(where: \.isDefault) { diaChi = macDinh.diaChi }
            if let gia { giaLyBiMat = gia }
        }
    }

    private var formView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("🎁").font(.system(size: 48))
                Text("Ly Bí Mật").font(.system(size: 20, weight: .bold))
                Text("Chỉ \(formatTien(giaLyBiMat)), quán sẽ chọn NGẪU NHIÊN 1 món cho bạn — có thể là món giá cao hơn nhiều! Thử vận may của bạn 🍀")
                    .font(.system(size: 14)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Giao đến").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
                    TextField("Nhập địa chỉ giao hàng...", text: $diaChi, axis: .vertical).textFieldStyle(.roundedBorder)
                    if !savedDiaChi.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(savedDiaChi) { d in
                                    Button((d.isDefault ? "★ " : "") + d.diaChi) { diaChi = d.diaChi }
                                        .font(.system(size: 12)).lineLimit(1)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.divider))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !error.isEmpty { Text(error).foregroundColor(Theme.danger) }

                Button {
                    Task { await boc() }
                } label: {
                    if loading { ProgressView().tint(.white) } else { Text("Bốc Ly Bí Mật 🎲").fontWeight(.bold) }
                }
                .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
                .disabled(loading)
            }
            .padding(20)
        }
    }

    private func revealView(_ result: LyBiMatResult) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🎉").font(.system(size: 60))
            Text("Bạn nhận được").foregroundColor(Theme.textMuted)
            Text("\(result.tenSanPham) (\(result.tenBienThe))").font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
            Text("Trả \(formatTien(result.giaTraTien)) — giá thật \(formatTien(result.giaThat))").foregroundColor(Theme.textMuted)
            if result.tietKiem > 0 {
                Text("Bạn đã tiết kiệm \(formatTien(result.tietKiem))! 🎊").font(.system(size: 15, weight: .bold)).foregroundColor(Theme.success)
            }
            Text("Mã đơn: \(result.maHoaDon)").font(.system(size: 12)).foregroundColor(Theme.textFaint)

            Button("Thanh toán") { path.append(.thanhToan(hoaDonId: result.hoaDonId)) }
                .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
            Button("Bốc thêm 1 ly khác") { self.result = nil }
                .foregroundColor(Theme.primary)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    private func boc() async {
        guard !diaChi.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Vui lòng nhập địa chỉ giao hàng."
            return
        }
        loading = true; error = ""
        defer { loading = false }
        if clientOrderId == nil { clientOrderId = UUID().uuidString }
        let res = await APIClient.shared.datLyBiMat(diaChiText: diaChi.trimmingCharacters(in: .whitespaces), ghiChu: nil, clientOrderId: clientOrderId)
        if res.isSuccess, let data = res.data {
            clientOrderId = nil
            result = data
        } else {
            error = res.message ?? "Có lỗi xảy ra, thử lại nhé."
        }
    }
}
