import SwiftUI

/// Tab "Voucher" riêng — TÁCH ra khỏi tab Ưu đãi (2026-09-15, trước đó nằm chung trong 1 ô nhỏ ở
/// UuDaiView) để voucher trang trọng hơn, mỗi voucher là 1 card riêng kiểu "vé" (tham khảo card mã
/// giảm giá Shopee: khối giá trị giảm bên trái + đường đứt nét có khoét tròn ở giữa + thông tin bên
/// phải), thay vì list rời rạc chữ-với-chữ trong 1 card chung.
struct VoucherCuaToiView: View {
    var notificationBell: AnyView

    @State private var vouchers: [VoucherCuaToi] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Voucher", icon: "ticket", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    fullScreenLoading()
                } else if vouchers.isEmpty {
                    // Bọc ScrollView để .refreshable hoạt động cả khi rỗng (không thì khách kẹt
                    // "chưa có voucher" không vuốt xuống tải lại được).
                    ScrollView { emptyState }
                        .refreshable { await load() }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(vouchers) { v in
                                VoucherTicketCard(
                                    ten: v.ten, moTa: v.moTa, ma: v.ma,
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket").font(.system(size: 40)).foregroundColor(Theme.textFaint)
            Text("Bạn chưa có voucher nào").font(.system(size: 14)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        vouchers = await APIClient.shared.getVoucherCuaToi()
        loading = false
    }
}

// Card hiển thị (VoucherTicketCard) đã tách sang file riêng — dùng chung với sheet "Chọn voucher"
// ở CheckoutView. Xem VoucherTicketCard.swift.
