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

    /// Khả dụng: giá trị giảm THẤP nhất lên đầu (đổi 2026-09-28, feedback: bản 27/9 sắp cao->thấp bị
    /// ngược) — trước đó giữ nguyên thứ tự NgayTao server trả, không phản ánh voucher nào "đáng dùng"
    /// hơn.
    private var dangCo: [VoucherCuaToi] {
        vouchers.filter { !$0.chuaBatDau && !$0.daSuDung }
            .sorted { $0.giaTriGiamThamKhao < $1.giaTriGiamThamKhao }
    }

    /// Voucher "chưa tới ngày" (lễ tết còn xa) — server trả sẵn qua cờ chuaBatDau (dùng chung 1 cửa sổ
    /// SoNgayHienTruoc/voucher, gom về 1 nguồn 2026-09-27, xem DatHangService.GetVoucherSapCoAsync).
    /// Sắp theo NGÀY GẦN NHẤT lên trước (feedback 2026-09-27) — khác các voucher "không khả dụng"
    /// khác: lễ tết cần biết dịp nào TỚI TRƯỚC để canh quay lại, không phải giảm nhiều hay ít.
    private var chuaToiNgay: [VoucherCuaToi] {
        vouchers.filter { $0.chuaBatDau }
            .sorted { ($0.ngayBatDau ?? "") < ($1.ngayBatDau ?? "") }
    }

    /// Đã dùng (KHÔNG tính voucher lễ tết chuaBatDau=true trùng lặp — vd voucher lặp hằng năm vừa
    /// dùng xong năm nay vừa chờ năm sau, đã thuộc chuaToiNgay ở trên, tránh hiện 2 lần). Sắp theo
    /// giá trị giảm cao nhất trước, giống mọi voucher "không khả dụng" khác trừ lễ tết.
    private var daDungKhongLeTet: [VoucherCuaToi] {
        vouchers.filter { $0.daSuDung && !$0.chuaBatDau }
            .sorted { $0.giaTriGiamThamKhao > $1.giaTriGiamThamKhao }
    }

    /// Chưa đủ điều kiện dù đã tới ngày — sắp theo giá trị giảm cao nhất trước, cùng tiêu chí với
    /// nhóm "không khả dụng" khác (khác lễ tết ở trên).
    private var voucherSapCoSapXep: [VoucherCuaToi] {
        voucherSapCo.sorted { $0.giaTriGiamThamKhao > $1.giaTriGiamThamKhao }
    }

    /// ID các voucher "Sắp có" (gộp cả 2 lý do: chưa tới ngày + chưa đủ điều kiện) — dùng để làm MỜ
    /// đúng những dòng này khi chúng xuất hiện gộp chung trong tab TẤT CẢ (voucherSapCo tự thân không
    /// mang cờ daSuDung/chuaBatDau nào để VoucherTicketCard tự mờ qua nhanSapDienRa, phải đánh dấu từ
    /// bên ngoài qua forceMo — chuaToiNgay thì tự có nhanSapDienRa nên không cần trong set này).
    private var sapCoIds: Set<String> { Set(voucherSapCo.map(\.id)) }

    private var hienThi: [VoucherCuaToi] {
        switch tab {
        // TẤT CẢ = gộp cả 2 danh sách (Đang có/Sắp có), khả dụng lên đầu — chưa khả dụng (đã dùng/
        // chưa tới ngày/voucherSapCo) dồn xuống dưới rồi mờ đi, mỗi khối tự sắp theo tiêu chí riêng.
        case .tatCa: return dangCo + daDungKhongLeTet + chuaToiNgay + voucherSapCoSapXep
        case .dangCo: return dangCo
        // SẮP CÓ = chưa tới ngày (chuaToiNgay, sắp theo ngày) + chưa đủ điều kiện dù đã tới ngày
        // (voucherSapCoSapXep, sắp theo giá trị giảm) — 2 nguồn cùng 1 cửa sổ hiện-trước ở server,
        // chỉ khác lý do hiển thị VÀ tiêu chí sắp xếp.
        case .sapCo: return chuaToiNgay + voucherSapCoSapXep
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
                                    nhanSoLan: v.nhanSoLan, nhanSapDienRa: v.nhanSapDienRa,
                                    // Chỉ tab TẤT CẢ trộn khả dụng/chưa khả dụng mới cần mờ để phân
                                    // biệt — ĐANG CÓ (toàn khả dụng) và SẮP CÓ (toàn chưa khả dụng)
                                    // đồng nhất 1 trạng thái, mờ ở 2 tab đó chỉ dư thừa.
                                    applyDim: tab == .tatCa,
                                    // Voucher "sắp có" loại "chưa đủ điều kiện" (không có nhanSapDienRa)
                                    // không tự mờ được từ card qua daSuDung/nhanSapDienRa — ép mờ qua
                                    // forceMo, KHÔNG dùng .opacity() overlay riêng nữa (2026-09-27 fix:
                                    // overlay riêng chỉ nhân mờ lên khối trái vẫn tô đậm primaryGradient,
                                    // nhìn ĐẬM HƠN hẳn card mờ kiểu textFaint dù cùng hệ số — "2 độ mờ
                                    // khác nhau"). forceMo đi qua chung `mo` nên khối trái cũng đổi màu
                                    // xám textFaint đồng bộ.
                                    forceMo: tab == .tatCa && sapCoIds.contains(v.id) && v.nhanSapDienRa == nil && !v.daSuDung
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

    /// 2026-09-27: BỎ hẳn phần ghép "— Cần: ..." theo phản hồi (dòng lý do chưa mở khoá làm rối card,
    /// nhãn "SẮP CÓ"/mờ card đã đủ ngụ ý "chưa dùng được") — chỉ còn hiện moTa gốc staff gõ sẵn, không
    /// đụng gì tới lyDoChuaKhaDung ở nơi khác (model vẫn giữ field này).
    private func moTaHienThi(_ v: VoucherCuaToi) -> String? { v.moTa }

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
