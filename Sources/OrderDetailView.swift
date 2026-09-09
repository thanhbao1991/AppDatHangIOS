import SwiftUI

/// Port từ OrderDetailScreen.tsx — timeline trạng thái, danh sách món, tổng kết tiền, huỷ/đặt lại/
/// đánh giá đơn.
struct OrderDetailView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var donHangPath: [DonHangRoute]
    @Binding var selectedTab: AppTab
    @Binding var cartPath: [HomeRoute]
    @Environment(\.dismiss) private var dismiss

    @State var order: DonHangKhach

    @State private var daDanhGia = false
    @State private var soSaoDaDanh = 0
    @State private var pickSao = 0
    @State private var nhanXet = ""
    @State private var dangGui = false
    @State private var dangHuy = false
    @State private var showHuyConfirm = false

    private let steps: [TrangThaiDon] = [.choXacNhan, .daXacNhan, .dangGiao, .hoanTat]
    private var currentStep: Int { steps.firstIndex(of: order.trangThai) ?? 0 }

    /// "Mặc định"/"Size Chuẩn"/"Chuẩn" là biến thể mặc định — khớp bienTheSuffix bên AppQuanLyIOS.
    private func bienTheSuffix(_ ten: String) -> String {
        ["", "Mặc định", "Size Chuẩn", "Chuẩn"].contains(ten) ? "" : " (\(ten))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                card {
                    HStack {
                        Text(order.maHoaDon).fontWeight(.bold)
                        Spacer()
                        Text(order.ngayGio).font(.system(size: 12)).foregroundColor(Theme.textFaint)
                    }
                    timeline
                }

                card {
                    Text(order.phanLoai == "Ship" ? "Giao đến" : "Hình thức").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
                    if order.phanLoai == "Ship" {
                        Text(order.diaChiText ?? "—")
                        if let sdt = order.soDienThoaiText { Text("SĐT: \(sdt)").foregroundColor(Theme.textMuted).font(.system(size: 13)) }
                    } else {
                        Text(order.phanLoai == "Mv" ? "Mang về" : "Tại quán\(order.tenBan.map { " — Bàn \($0)" } ?? "")")
                    }
                    if let ghiChu = order.ghiChu, !ghiChu.isEmpty {
                        Text("Ghi chú: \(ghiChu)").foregroundColor(Theme.textMuted).font(.system(size: 13))
                    }
                }

                card {
                    HStack {
                        Label("Món", systemImage: "cup.and.saucer.fill")
                        Spacer()
                        Text("\(order.items.reduce(0) { $0 + $1.soLuong }) ly")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.primary)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.primaryTint).clipShape(Capsule())
                    }
                    ForEach(order.items) { it in
                        HStack(spacing: 10) {
                            Text("\(it.soLuong)")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                .frame(width: 22, height: 22).background(Theme.primary).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(it.tenSanPham)\(bienTheSuffix(it.tenBienThe))").font(.system(size: 15, weight: .bold))
                                if !it.toppings.isEmpty {
                                    Text("+ " + it.toppings.map { $0.soLuong > 1 ? "\($0.ten) x\($0.soLuong)" : $0.ten }.joined(separator: ", ")).font(.system(size: 12)).foregroundColor(Theme.primary)
                                }
                                if let ghiChu = it.ghiChu, !ghiChu.isEmpty {
                                    Text("Ghi chú: \(ghiChu)").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                                }
                            }
                            Spacer()
                            Text(formatTien(Double(it.soLuong) * (it.donGia + it.toppings.reduce(0) { $0 + $1.gia * Double($1.soLuong) }))).font(.system(size: 15, weight: .bold))
                        }
                        .padding(.vertical, 6)
                    }
                }

                card {
                    infoRow("Tổng tiền", order.tongTien)
                    if order.giamGia > 0 { infoRow("Giảm giá", order.giamGia) }
                    infoRow("Thành tiền", order.thanhTien)
                    infoRow("Đã thu", order.daThu)
                    Divider()
                    HStack {
                        Text("CÒN LẠI").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textMuted)
                        Spacer()
                        Text(formatTien(order.conLai)).font(.system(size: 20, weight: .bold))
                            .foregroundColor(order.conLai > 0 ? Theme.danger : Theme.success)
                    }
                }

                if order.trangThai != .hoanTat {
                    Button("💳 Thanh toán") { donHangPath.append(.thanhToan(hoaDonId: order.id)) }
                        .buttonStyle(.borderedProminent).tint(Theme.primary).frame(maxWidth: .infinity)
                }

                if order.trangThai == .choXacNhan {
                    Button(role: .destructive) { showHuyConfirm = true } label: {
                        if dangHuy { ProgressView() } else { Text("Huỷ đơn").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.bordered).disabled(dangHuy)
                }

                Button("🔁 Đặt lại") { datLai() }
                    .buttonStyle(.bordered).tint(Theme.primary).frame(maxWidth: .infinity)

                if order.trangThai == .hoanTat {
                    card { danhGiaSection }
                }
            }
            .padding()
        }
        .navigationTitle("Chi tiết đơn hàng")
        .navigationBarTitleDisplayMode(.inline)
        .brandNavBar()
        .onAppear {
            daDanhGia = order.daDanhGia
            soSaoDaDanh = order.soSaoDaDanh ?? 0
        }
        .task { await reload() }
        .confirmationDialog("Huỷ đơn \(order.maHoaDon)?", isPresented: $showHuyConfirm, titleVisibility: .visible) {
            Button("Huỷ đơn", role: .destructive) { Task { await huyDon() } }
            Button("Không", role: .cancel) {}
        } message: {
            Text("Đơn sẽ bị huỷ, không thể hoàn tác.")
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).foregroundColor(Theme.textMuted)
            Spacer()
            Text(formatTien(value))
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle().fill(i <= currentStep ? Theme.primary : Theme.divider).frame(width: 12, height: 12)
                        if i < steps.count - 1 {
                            Rectangle().fill(i < currentStep ? Theme.primary : Theme.divider).frame(width: 2, height: 28)
                        }
                    }
                    Text(step.nhan)
                        .font(.system(size: 13, weight: i <= currentStep ? .semibold : .regular))
                        .foregroundColor(i <= currentStep ? .primary : Theme.textFaint)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var danhGiaSection: some View {
        Text("Đánh giá").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.primary)
        if daDanhGia {
            Text("Bạn đã đánh giá \(String(repeating: "⭐", count: soSaoDaDanh)) — Cảm ơn bạn!")
        } else {
            HStack {
                ForEach(1...5, id: \.self) { n in
                    Button { pickSao = n } label: {
                        Text(n <= pickSao ? "⭐" : "☆").font(.system(size: 28))
                    }
                }
            }
            TextField("Nhận xét (không bắt buộc)", text: $nhanXet).textFieldStyle(.roundedBorder)
            Button {
                Task { await guiDanhGia() }
            } label: {
                if dangGui { ProgressView().tint(.white) } else { Text("Gửi đánh giá").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent).tint(Theme.primary).disabled(pickSao == 0 || dangGui)
        }
    }

    private func reload() async {
        let list = await APIClient.shared.getDonCuaToi()
        guard let moi = list.first(where: { $0.id == order.id }) else { return }
        order = moi
        if moi.daDanhGia {
            daDanhGia = true
            soSaoDaDanh = moi.soSaoDaDanh ?? 0
        }
    }

    private func huyDon() async {
        dangHuy = true
        defer { dangHuy = false }
        let result = await APIClient.shared.huyDon(order.id)
        if result.success { dismiss() }
    }

    private func datLai() {
        cart.clear()
        for it in order.items {
            cart.addItem(sanPhamBienTheId: it.sanPhamBienTheId, tenSanPham: it.tenSanPham, tenBienThe: it.tenBienThe, giaBan: it.donGia, soLuong: it.soLuong, ghiChu: it.ghiChu, toppings: it.toppings.map { CartTopping(id: $0.toppingId, ten: $0.ten, gia: $0.gia, soLuong: $0.soLuong) })
        }
        cartPath = []
        selectedTab = .cart
    }

    private func guiDanhGia() async {
        guard pickSao > 0 else { return }
        dangGui = true
        defer { dangGui = false }
        let result = await APIClient.shared.danhGiaDon(hoaDonId: order.id, soSao: pickSao, nhanXet: nhanXet.isEmpty ? nil : nhanXet)
        if result.success {
            daDanhGia = true
            soSaoDaDanh = pickSao
        }
    }
}
