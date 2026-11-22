import SwiftUI

/// Tab "Voucher" — card kiểu vé (VoucherTicketCard). 17/11/2026 (chủ quán): làm GIỐNG sheet "Chọn voucher" cho gọn —
/// cùng nguồn GET /voucher/chon (thứ tự kéo-thả ở AppQuanLyIOS, tên/mô tả đã bỏ mức giảm vì khối trái thẻ đã ghi, dòng
/// hướng dẫn cam trong thẻ cho voucher chưa dùng được, không dòng mã). Khác sheet: không có giỏ hàng nên mọi voucher
/// tài khoản dùng được đều xếp nhóm "dùng được"; voucher ĐÃ dùng vẫn hiện cuối (mờ, nhãn "Đã sử dụng") để khách xem lại.
struct VoucherCuaToiView: View {
    var notificationBell: AnyView
    /// false khi nhúng trong UuDaiVoucherView (thanh tiêu đề do view cha vẽ).
    var showHeader: Bool = true

    @State private var chon: VoucherChon? = CartStore.docVoucherChonDaLuu()
    @State private var cuaToi: [VoucherCuaToi] = []
    @State private var loading = true
    @State private var huongDan: (ten: String, lyDo: String)?

    @EnvironmentObject private var cart: CartStore

    /// CÙNG hàm xếp với sheet "Chọn voucher" (DongVoucher.xep) và CÙNG giỏ hàng hiện tại để quyết định "dùng được" —
    /// 2 màn giống hệt nhau (chủ quán 22/11/2026). Voucher đã dùng hẳn: server gửi chon.daDung (bản server cũ thì lọc cuaToi).
    private var hienThi: [DongVoucher] {
        let daDung = chon?.daDung ?? cuaToi.filter { $0.daSuDung && !$0.chuaBatDau }
        return DongVoucher.xep(khaDung: chon?.khaDung ?? [], chuaDung: chon?.chuaDung ?? [], daDung: daDung,
                               thuTuNhom: chon?.thuTuNhom ?? [], thuTuId: chon?.thuTuId ?? [],
                               duDieuKien: cart.voucherDuDieuKien)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHeader { TitleBar(title: "Voucher", icon: "ticket", centerTitle: true, trailing: notificationBell) }

            Group {
                if loading && hienThi.isEmpty {
                    fullScreenLoading()
                } else if hienThi.isEmpty {
                    // Bọc ScrollView để .refreshable hoạt động cả khi rỗng.
                    ScrollView { emptyState }
                        .refreshable { await load() }
                } else {
                    List {
                        ForEach(hienThi) { d in card(for: d).tkDongList(cach: 12) }
                    }
                    .tkList(cach: 12)
                    .refreshable { await load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        .task { await load() }
        .alert(huongDan?.ten ?? "", isPresented: Binding(get: { huongDan != nil }, set: { if !$0 { huongDan = nil } })) {
            Button(chu("Đã hiểu")) {}
        } message: {
            Text(huongDan?.lyDo ?? "")
        }
    }

    /// Hàm trả về KIỂU CỤ THỂ (AnyView) thay vì gộp vào ForEach trong body — tránh Swift type-checker quá thời gian.
    private func card(for d: DongVoucher) -> AnyView {
        switch d {
        case .khaDung(let v):
            // Giống sheet: chưa đủ điều kiện với giỏ thì ghi cách dùng trong thẻ, bấm xem lý do.
            let ok = cart.voucherDuDieuKien(v)
            let lyDo = cart.lyDoChuaDuDieuKien(v)
            return AnyView(Button { if !ok { huongDan = (v.ten, lyDo ?? "Voucher này chưa áp dụng được cho giỏ hàng hiện tại.") } } label: {
                VoucherTicketCard(
                    ten: v.tenNgan ?? v.ten, moTa: v.moTaNgan ?? v.moTa, ma: v.ma,
                    nhanGiam: v.nhanGiamGia, nhanGiamToiDa: v.nhanGiamToiDa,
                    donToiThieu: v.donToiThieu,
                    huongDan: ok ? nil : VoucherPickerSheet.cachDungNgan(lyDo),
                    hienMa: false,
                    hienMoTa: ok
                )
            }
            .buttonStyle(.plain))
        case .chuaDung(let v):
            let lyDo = v.lyDoChuaKhaDung ?? "Chưa đủ điều kiện dùng."
            return AnyView(Button { huongDan = (v.ten, lyDo) } label: {
                VoucherTicketCard(
                    ten: v.tenNgan ?? v.ten, moTa: v.moTaNgan ?? v.moTa, ma: v.ma,
                    nhanGiam: v.nhanGiamGia, nhanGiamToiDa: v.nhanGiamToiDa,
                    donToiThieu: v.donToiThieu,
                    nhanSoLan: v.nhanSoLan,
                    applyDim: false,
                    hangYeuCau: v.hangToiThieu,
                    huongDan: lyDo,
                    hienMa: false,
                    hienMoTa: false
                )
            }
            .buttonStyle(.plain))
        case .daDung(let v):
            return AnyView(VoucherTicketCard(
                ten: v.tenNgan ?? v.ten, moTa: v.moTaNgan ?? v.moTa, ma: v.ma,
                nhanGiam: v.nhanGiamGia, nhanGiamToiDa: v.nhanGiamToiDa,
                donToiThieu: v.donToiThieu, daSuDung: true,
                nhanSoLan: v.nhanSoLan,
                hienMa: false
            ))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket").font(.system(size: 40)).foregroundColor(Theme.textFaint)
            Text(chu("Bạn chưa có voucher nào"))
                .font(.system(size: 14)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        async let chonTask = APIClient.shared.getVoucherChon()
        async let cuaToiTask = APIClient.shared.getVoucherCuaToi()
        if let moi = await chonTask { chon = moi; CartStore.luuVoucherChon(moi) }
        cuaToi = await cuaToiTask
        loading = false
    }
}
