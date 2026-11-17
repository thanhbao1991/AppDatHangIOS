import SwiftUI

/// Sheet "Chọn voucher" dùng chung cho Giỏ hàng VÀ Thanh toán (2026-09-27) — tách khỏi CheckoutView
/// (nơi sinh ra UI này đầu tiên) khi chuyển việc chọn ưu đãi lên tab Giỏ hàng theo yêu cầu tham khảo
/// Long Châu. Nhận `selected` là Binding TRỰC TIẾP vào CartStore.selectedVoucher — không giữ bản sao
/// riêng ở tầng gọi, tránh 2 nơi lệch nhau.
struct VoucherPickerSheet: View {
    let vouchers: [Voucher]
    /// Voucher chưa dùng được (chưa tới ngày / chưa đủ hạng-điều kiện), KHÔNG gồm voucher đã dùng — hiện dưới cùng để
    /// khách biết có gì đang chờ (chủ quán 2026-11-17). Bấm chỉ hiện lý do, không chọn được. Xem CartStore.voucherChuaDung.
    var voucherChuaDung: [VoucherCuaToi] = []
    /// Thứ tự nhóm do backend quyết định (CartStore.thuTuNhomVoucher), xem dongHienThi. Thiếu
    /// nhóm nào thì nhóm đó nối cuối theo thứ tự mặc định.
    var thuTuNhom: [String] = []
    /// Thứ tự toàn bộ voucher (Id) khi thuTuNhom = ["tatCa"] — xem VoucherChon.thuTuId.
    var thuTuId: [String] = []
    let duDieuKien: (Voucher) -> Bool
    /// Số tiền giảm thực tế cho đơn hiện tại (Voucher.soTienGiamThucTe áp cho tongTienHang của giỏ) —
    /// dùng để xếp hạng trong mỗi nhóm, KHÔNG dùng để quyết định khả dụng (đã có duDieuKien riêng).
    let giaTriGiam: (Voucher) -> Double
    /// Vì sao chưa dùng được + cách dùng (CartStore.lyDoChuaDuDieuKien) — hiện khi bấm voucher chưa đủ điều kiện.
    var lyDo: (Voucher) -> String? = { _ in nil }
    @Binding var selected: Voucher?
    @State private var huongDan: (ten: String, lyDo: String)?
    var onClose: () -> Void
    /// Tải lại danh sách voucher — dùng cho nút "Thử tải lại" khi `vouchers` rỗng. Thêm 2026-09-28
    /// (feedback: sheet trắng tinh khi request /voucher/kha-dung rớt mạng giữa chừng, APIClient nuốt
    /// lỗi âm thầm trả về [] nên KHÔNG phân biệt được "thật sự hết voucher" hay "tải lỗi") — không có
    /// context riêng để tự biết lỗi hay hết thật, nên luôn hiện nút thử lại kèm câu giải thích cả 2
    /// khả năng, để khách tự quyết định thay vì đứng nhìn màn trắng không rõ đang chờ gì.
    var onRetry: () async -> Void
    @State private var retrying = false

    private enum Dong: Identifiable {
        case khaDung(Voucher), chuaDung(VoucherCuaToi)
        var id: String {
            switch self { case .khaDung(let v): return v.id; case .chuaDung(let v): return v.id }
        }
    }

    /// Thứ tự hiển thị do backend quyết định (GET /voucher/chon): `thuTuId` = thứ tự kéo-thả ở AppQuanLyIOS, `thuTuNhom` =
    /// lần lượt lấy nhóm nào trước — "dungDuoc" (đủ điều kiện với giỏ), "chuaDung", "thieuDieuKien", "tatCa" (mọi voucher
    /// còn lại). Trong mỗi nhóm giữ thứ tự `thuTuId`. Voucher chưa nhóm nào lấy thì nối cuối. Chủ quán 2026-11-17: dùng
    /// được lên đầu, còn lại theo thứ tự server → server gửi ["dungDuoc", "tatCa"].
    private var dongHienThi: [Dong] {
        let viTri = Dictionary(thuTuId.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        var conLai = (vouchers.map(Dong.khaDung) + voucherChuaDung.map(Dong.chuaDung)).enumerated()
            .sorted { (viTri[$0.element.id] ?? Int.max, $0.offset) < (viTri[$1.element.id] ?? Int.max, $1.offset) }
            .map(\.element)
        let nhom = thuTuNhom.isEmpty ? ["dungDuoc", "chuaDung", "thieuDieuKien"] : thuTuNhom
        var kq: [Dong] = []
        for n in nhom + ["tatCa"] {
            let lay: (Dong) -> Bool
            switch n {
            case "dungDuoc": lay = { if case .khaDung(let v) = $0 { return duDieuKien(v) } else { return false } }
            case "thieuDieuKien": lay = { if case .khaDung(let v) = $0 { return !duDieuKien(v) } else { return false } }
            case "chuaDung": lay = { if case .chuaDung = $0 { return true } else { return false } }
            case "tatCa": lay = { _ in true }
            default: continue
            }
            kq += conLai.filter(lay)
            conLai.removeAll(where: lay)
        }
        return kq
    }

    var body: some View {
        NavigationStack {
            Group {
                if vouchers.isEmpty && voucherChuaDung.isEmpty {
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

    /// Phần "cách dùng" của lyDoChuaDuDieuKien (đoạn sau "\n\n", bỏ tiền tố "Cách dùng: ") để hiện thẳng dưới thẻ.
    static func cachDungNgan(_ lyDo: String?) -> String {
        guard let lyDo, !lyDo.isEmpty else { return "Chưa đủ điều kiện cho giỏ hàng hiện tại" }
        let doan = lyDo.components(separatedBy: "\n\n").last ?? lyDo
        let bo = doan.hasPrefix("Cách dùng: ") ? String(doan.dropFirst("Cách dùng: ".count)) : doan
        guard let dau = bo.first else { return lyDo }
        return dau.uppercased() + bo.dropFirst()
    }

    /// 1 dòng voucher của `vouchers` (dùng được ngay hoặc thiếu tiền đơn).
    @ViewBuilder
    private func dongVoucher(_ v: Voucher) -> some View {
        let ok = duDieuKien(v)
        cardRow {
            Button {
                // 09/11/2026: voucher chưa đủ điều kiện KHÔNG mờ/khoá nữa — bấm vào hiện lý do + cách dùng.
                guard ok else {
                    huongDan = (v.ten, lyDo(v) ?? "Voucher này chưa áp dụng được cho giỏ hàng hiện tại.")
                    return
                }
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
                VStack(alignment: .leading, spacing: 6) {
                    VoucherTicketCard(
                        ten: v.ten, moTa: v.moTa, ma: v.ma,
                        nhanGiam: v.nhanGiamGia,
                        nhanGiamToiDa: v.nhanGiamToiDa,
                        donToiThieu: v.donToiThieu,
                        daChon: selected?.id == v.id,
                        // 11/11/2026: hiện LUÔN cách dùng; 17/11/2026: đưa vào TRONG thẻ (để ngoài dễ nhầm thẻ dưới).
                        huongDan: ok ? nil : Self.cachDungNgan(lyDo(v)),
                        hienMa: false,
                        // Dùng được ngay (không dòng hướng dẫn) thì hiện mô tả cho thẻ khỏi trống; chưa dùng được thì dòng
                        // hướng dẫn thay mô tả (tránh lặp ý).
                        hienMoTa: ok
                    )
                }
                .padding(.horizontal).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    /// Voucher chưa dùng được (chưa tới ngày / chưa đủ hạng-điều kiện) — bấm chỉ hiện lý do. Dòng lý do = lyDoChuaKhaDung
    /// server soạn sẵn (gồm cả nhắc nhập ngày sinh cho voucher sinh nhật).
    private func dongVoucherChuaDung(_ v: VoucherCuaToi) -> some View {
        let lyDo = v.lyDoChuaKhaDung ?? "Chưa đủ điều kiện dùng."
        return cardRow {
            Button {
                huongDan = (v.ten, lyDo)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    VoucherTicketCard(
                        ten: v.ten, moTa: v.moTa, ma: v.ma,
                        nhanGiam: v.nhanGiamGia, nhanGiamToiDa: v.nhanGiamToiDa,
                        donToiThieu: v.donToiThieu,
                        // Không nhãn "Từ dd/MM" — dòng hướng dẫn đã ghi "Dùng được từ dd/MM." (tránh lặp).
                        nhanSoLan: v.nhanSoLan,
                        applyDim: false,
                        hangYeuCau: v.hangToiThieu,
                        huongDan: lyDo,
                        hienMa: false,
                        hienMoTa: false
                    )
                }
                .padding(.horizontal).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var voucherList: some View {
        List {
                // Bấm THẲNG vào voucher là chọn/áp dụng ngay, bấm lại voucher đang chọn là bỏ chọn NGAY
                // — bỏ hẳn bước "Áp dụng" riêng + state pending tạm (feedback 2026-09-27: chọn hay bỏ
                // voucher đều phải ăn liền, không bắt bấm thêm 1 nút mới có hiệu lực). Hiện TẤT CẢ
                // voucher (kể cả chưa đủ điều kiện Size L/topping) — mờ đi thay vì ẩn hẳn để khách biết
                // có voucher đang chờ, tạo động lực thêm món vào giỏ cho đủ điều kiện.
                ForEach(dongHienThi) { d in
                    switch d {
                    case .khaDung(let v): dongVoucher(v)
                    case .chuaDung(let v): dongVoucherChuaDung(v)
                    }
                }
        }
        .cardListBackground()
        .popupHost { host in
            host.alert(huongDan?.ten ?? "", isPresented: Binding(get: { huongDan != nil }, set: { if !$0 { huongDan = nil } })) {
                Button("Đã hiểu") {}
            } message: {
                Text(huongDan?.lyDo ?? "")
            }
        }
    }
}
