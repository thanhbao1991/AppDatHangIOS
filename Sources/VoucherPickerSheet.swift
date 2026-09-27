import SwiftUI

/// Sheet "Chọn voucher" dùng chung cho Giỏ hàng VÀ Thanh toán (2026-09-27) — tách khỏi CheckoutView
/// (nơi sinh ra UI này đầu tiên) khi chuyển việc chọn ưu đãi lên tab Giỏ hàng theo yêu cầu tham khảo
/// Long Châu. Nhận `selected` là Binding TRỰC TIẾP vào CartStore.selectedVoucher — không giữ bản sao
/// riêng ở tầng gọi, tránh 2 nơi lệch nhau.
struct VoucherPickerSheet: View {
    let vouchers: [Voucher]
    let duDieuKien: (Voucher) -> Bool
    @Binding var selected: Voucher?
    var onClose: () -> Void

    /// Lựa chọn TẠM trong sheet — chỉ ghi thật vào `selected` khi bấm "Áp dụng", để bấm "Đóng"/vuốt
    /// xuống không làm mất lựa chọn đã áp dụng trước đó.
    @State private var pending: Voucher?

    var body: some View {
        NavigationStack {
            List {
                // Không có dòng "Không dùng voucher" riêng — bấm lại voucher đang chọn để bỏ chọn, rồi
                // bấm "Áp dụng" để xác nhận. Hiện TẤT CẢ voucher (kể cả chưa đủ điều kiện Size L/
                // topping) — mờ đi thay vì ẩn hẳn để khách biết có voucher đang chờ, tạo động lực thêm
                // món vào giỏ cho đủ điều kiện.
                ForEach(vouchers) { v in
                    let ok = duDieuKien(v)
                    cardRow {
                        Button {
                            guard ok else { return }
                            pending = (pending?.id == v.id) ? nil : v
                        } label: {
                            // Hiện Y HỆT card ở tab Voucher (nhanGiam/nhanGiamToiDa) — không hiện số
                            // tiền quy đổi riêng cho đơn hiện tại, tránh cùng 1 voucher trông như 2
                            // voucher khác nhau giữa 2 màn.
                            VoucherTicketCard(
                                ten: v.ten, moTa: v.moTa, ma: v.ma,
                                nhanGiam: v.nhanGiamGia,
                                nhanGiamToiDa: v.nhanGiamToiDa,
                                donToiThieu: v.donToiThieu,
                                daChon: pending?.id == v.id
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
            .safeAreaInset(edge: .bottom) {
                Button {
                    selected = pending
                    onClose()
                } label: {
                    Text("Áp dụng")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                }
                .background(Color(.systemBackground).overlay(Divider(), alignment: .top))
            }
        }
        .onAppear { pending = selected }
    }
}
