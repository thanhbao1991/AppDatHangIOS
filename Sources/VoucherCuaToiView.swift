import SwiftUI

/// Tab "Voucher" riêng — TÁCH ra khỏi tab Ưu đãi (2026-09-15, trước đó nằm chung trong 1 ô nhỏ ở
/// UuDaiView) để voucher trang trọng hơn, mỗi voucher là 1 card riêng kiểu "vé" (tham khảo card mã
/// giảm giá Shopee: khối giá trị giảm bên trái + đường đứt nét có khoét tròn ở giữa + thông tin bên
/// phải), thay vì list rời rạc chữ-với-chữ trong 1 card chung.
///
/// 2026-09-26: từng thử đổi hẳn sang dòng chữ phẳng (bỏ VoucherTicketCard) nhưng nhìn không còn
/// giống bản gốc (phản hồi thực tế kèm ảnh so sánh) — LẤY LẠI đúng VoucherTicketCard cũ, chỉ THÊM
/// thanh tab TẤT CẢ/ĐANG CÓ/SẮP CÓ ở trên (giữ nguyên phần đã làm — voucher hệ thống khách chưa đủ
/// điều kiện, API getVoucherSapCo), không đụng gì tới cách hiển thị từng card.
struct VoucherCuaToiView: View {
    private enum LocTab: String, CaseIterable {
        case tatCa = "TẤT CẢ"
        case dangCo = "ĐANG CÓ"
        case sapCo = "SẮP CÓ"
    }

    var notificationBell: AnyView

    @State private var vouchers: [VoucherCuaToi] = []
    @State private var voucherSapCo: [VoucherCuaToi] = []
    @State private var loading = true
    @State private var tab: LocTab = .tatCa

    private var dangCo: [VoucherCuaToi] {
        vouchers.filter { !$0.chuaBatDau && !$0.daSuDung }
    }

    private var hienThi: [VoucherCuaToi] {
        switch tab {
        case .tatCa: return vouchers
        case .dangCo: return dangCo
        case .sapCo: return voucherSapCo
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Voucher", icon: "ticket", centerTitle: true, trailing: notificationBell)
            tabBar

            Group {
                if loading {
                    fullScreenLoading()
                } else if hienThi.isEmpty {
                    // Bọc ScrollView để .refreshable hoạt động cả khi rỗng (không thì khách kẹt
                    // "chưa có voucher" không vuốt xuống tải lại được).
                    ScrollView { emptyState }
                        .refreshable { await load() }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(hienThi) { v in
                                VoucherTicketCard(
                                    ten: v.ten, moTa: moTaHienThi(v), ma: v.ma,
                                    nhanGiam: v.nhanGiamGia, nhanGiamToiDa: v.nhanGiamToiDa,
                                    donToiThieu: v.donToiThieu, daSuDung: v.daSuDung,
                                    nhanSoLan: v.nhanSoLan, nhanSapDienRa: v.nhanSapDienRa
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .refreshable { await load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        .task { await load() }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(LocTab.allCases, id: \.self) { t in
                    Button {
                        tab = t
                    } label: {
                        VStack(spacing: 8) {
                            Text(t.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(tab == t ? Theme.primary : Theme.textMuted)
                            Rectangle()
                                .fill(tab == t ? Theme.primary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }
            }
            Divider()
        }
        .background(Color(.systemBackground))
    }

    /// Tab "Sắp có" không có moTa staff gõ sẵn cho lý do chưa mở khoá — ghép thêm "Cần: ..." vào
    /// cuối moTa gốc (nếu có) để vẫn hiện gọn trong 1 dòng moTa có sẵn của VoucherTicketCard, không
    /// phải sửa thêm field mới cho card dùng chung với sheet "Chọn voucher".
    private func moTaHienThi(_ v: VoucherCuaToi) -> String? {
        guard let lyDo = v.lyDoChuaKhaDung else { return v.moTa }
        let goc = (v.moTa ?? "").trimmingCharacters(in: .whitespaces)
        return goc.isEmpty ? "Cần: \(lyDo)" : "\(goc) — Cần: \(lyDo)"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket").font(.system(size: 40)).foregroundColor(Theme.textFaint)
            Text(tab == .sapCo ? "Chưa có ưu đãi nào sắp mở khoá." : "Bạn chưa có voucher nào")
                .font(.system(size: 14)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        async let vouchersTask = APIClient.shared.getVoucherCuaToi()
        async let sapCoTask = APIClient.shared.getVoucherSapCo()
        vouchers = await vouchersTask
        voucherSapCo = await sapCoTask
        loading = false
    }
}

// Card hiển thị (VoucherTicketCard) đã tách sang file riêng — dùng chung với sheet "Chọn voucher"
// ở CheckoutView. Xem VoucherTicketCard.swift.
