import SwiftUI

/// Sheet "Chọn voucher" dùng chung cho Giỏ hàng VÀ Thanh toán (2026-09-27) — tách khỏi CheckoutView
/// (nơi sinh ra UI này đầu tiên) khi chuyển việc chọn ưu đãi lên tab Giỏ hàng theo yêu cầu tham khảo
/// Long Châu. Nhận `selected` là Binding TRỰC TIẾP vào CartStore.selectedVoucher — không giữ bản sao
/// riêng ở tầng gọi, tránh 2 nơi lệch nhau.
struct VoucherPickerSheet: View {
    let vouchers: [Voucher]
    let duDieuKien: (Voucher) -> Bool
    /// Số tiền giảm thực tế cho đơn hiện tại (Voucher.soTienGiamThucTe áp cho tongTienHang của giỏ) —
    /// dùng để xếp hạng trong mỗi nhóm, KHÔNG dùng để quyết định khả dụng (đã có duDieuKien riêng).
    let giaTriGiam: (Voucher) -> Double
    @Binding var selected: Voucher?
    var onClose: () -> Void

    /// Voucher DÙNG ĐƯỢC NGAY lên trước, voucher chưa đủ điều kiện xuống dưới (feedback 2026-09-27) —
    /// trong MỖI nhóm, giá trị giảm thực tế cho đơn hiện tại càng cao càng lên trên (feedback tiếp
    /// theo cùng ngày) thay vì giữ nguyên thứ tự server trả.
    private var sortedVouchers: [Voucher] {
        vouchers.sorted { a, b in
            let okA = duDieuKien(a), okB = duDieuKien(b)
            if okA != okB { return okA }
            return giaTriGiam(a) > giaTriGiam(b)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Bấm THẲNG vào voucher là chọn/áp dụng ngay, bấm lại voucher đang chọn là bỏ chọn NGAY
                // — bỏ hẳn bước "Áp dụng" riêng + state pending tạm (feedback 2026-09-27: chọn hay bỏ
                // voucher đều phải ăn liền, không bắt bấm thêm 1 nút mới có hiệu lực). Hiện TẤT CẢ
                // voucher (kể cả chưa đủ điều kiện Size L/topping) — mờ đi thay vì ẩn hẳn để khách biết
                // có voucher đang chờ, tạo động lực thêm món vào giỏ cho đủ điều kiện.
                ForEach(sortedVouchers) { v in
                    let ok = duDieuKien(v)
                    cardRow {
                        Button {
                            guard ok else { return }
                            selected = (selected?.id == v.id) ? nil : v
                            onClose()
                        } label: {
                            // Hiện Y HỆT card ở tab Voucher (nhanGiam/nhanGiamToiDa) — không hiện số
                            // tiền quy đổi riêng cho đơn hiện tại, tránh cùng 1 voucher trông như 2
                            // voucher khác nhau giữa 2 màn.
                            VoucherTicketCard(
                                ten: v.ten, moTa: v.moTa, ma: v.ma,
                                nhanGiam: v.nhanGiamGia,
                                nhanGiamToiDa: v.nhanGiamToiDa,
                                donToiThieu: v.donToiThieu,
                                daChon: selected?.id == v.id
                            )
                            .padding(.horizontal).padding(.vertical, 6)
                            .opacity(ok ? 1 : 0.4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!ok)
                    }
                }
            }
            .cardListBackground()
            .navigationTitle("Chọn voucher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onClose() }
                }
            }
        }
    }
}
