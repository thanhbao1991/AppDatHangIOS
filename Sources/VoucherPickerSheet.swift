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
    /// Tải lại danh sách voucher — dùng cho nút "Thử tải lại" khi `vouchers` rỗng. Thêm 2026-09-28
    /// (feedback: sheet trắng tinh khi request /voucher/kha-dung rớt mạng giữa chừng, APIClient nuốt
    /// lỗi âm thầm trả về [] nên KHÔNG phân biệt được "thật sự hết voucher" hay "tải lỗi") — không có
    /// context riêng để tự biết lỗi hay hết thật, nên luôn hiện nút thử lại kèm câu giải thích cả 2
    /// khả năng, để khách tự quyết định thay vì đứng nhìn màn trắng không rõ đang chờ gì.
    var onRetry: () async -> Void
    @State private var retrying = false

    /// Voucher DÙNG ĐƯỢC NGAY lên trước, voucher chưa đủ điều kiện xuống dưới (feedback 2026-09-27) —
    /// trong nhóm ĐÃ đủ điều kiện, giá trị giảm thực tế cho đơn hiện tại càng cao càng lên trên
    /// (feedback tiếp theo cùng ngày).
    ///
    /// Nhóm CHƯA đủ điều kiện: voucher KHÔNG có ngưỡng đơn tối thiểu (topping/upsize/đặt lại...) lên
    /// trước — không phụ thuộc khách mua thêm bao nhiêu tiền, chỉ cần đúng hành động là dùng được, nên
    /// "gần đạt" hơn nhóm có ngưỡng. Trong đó xếp theo giá trị tham khảo giamToiDa/soTienGiam. Nhóm CÓ
    /// ngưỡng xuống dưới, sắp theo ngưỡng THẤP nhất lên trước (đổi 2026-09-28, feedback: "nhìn không
    /// có thứ tự gì") — voucher càng gần đạt ngưỡng càng đáng khuyến khích thêm món hơn. KHÔNG dùng
    /// giaTriGiam(v) làm khoá cho nhóm ngưỡng vì hàm đó tính như đơn ĐÃ đạt ngưỡng (soTienGiamThucTe
    /// không tự kiểm donToiThieu), nên nhiều voucher bậc thang (DON300K/500K/1000K) ra cùng 1 số tiền
    /// giảm tại đơn hiện tại — trông như KHÔNG sắp xếp gì.
    private var sortedVouchers: [Voucher] {
        vouchers.sorted { a, b in
            let okA = duDieuKien(a), okB = duDieuKien(b)
            if okA != okB { return okA }
            if okA { return giaTriGiam(a) > giaTriGiam(b) }
            switch (a.donToiThieu, b.donToiThieu) {
            case let (da?, db?): return da < db
            case (.some, nil): return false
            case (nil, .some): return true
            case (nil, nil): return a.giaTriGiamThamKhao > b.giaTriGiamThamKhao
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vouchers.isEmpty {
                    emptyState
                } else {
                    voucherList
                }
            }
            .navigationTitle("Chọn voucher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onClose() }
                }
            }
        }
    }

    /// Trắng tinh không kèm giải thích khiến khách tưởng app treo (feedback 2026-09-28) — dù nguyên
    /// nhân thật (mất mạng giữa chừng lúc tải) hay hiếm khi thật sự hết voucher, đều nên có CHỮ +
    /// nút hành động thay vì im lặng.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ticket").font(.system(size: 40)).foregroundColor(Theme.textFaint)
            Text("Chưa tải được voucher, hoặc hiện không có voucher nào khả dụng.")
                .font(.system(size: 14)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                retrying = true
                Task { await onRetry(); retrying = false }
            } label: {
                if retrying { ProgressView().tint(.white) } else { Text("Thử tải lại") }
            }
            .buttonStyle(.gradientProminent)
            .frame(maxWidth: 200)
            .disabled(retrying)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var voucherList: some View {
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
                            // Đóng sheet TRƯỚC, chỉ ghi `selected` SAU khi sheet đã đóng xong (~0.35s,
                            // khớp thời gian dismiss mặc định của sheet) — nếu ghi ngay rồi đóng cùng
                            // lúc, số tiền ở màn dưới đổi trong lúc sheet còn che nên hiệu ứng đếm giảm
                            // (contentTransition numericText ở GioHangView/CheckoutView) chạy xong mà
                            // khách không thấy được (feedback 2026-09-27: "chọn voucher chưa thấy hiệu
                            // ứng, tại xảy ra nhanh quá").
                            let newValue: Voucher? = (selected?.id == v.id) ? nil : v
                            onClose()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                selected = newValue
                            }
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
    }
}
