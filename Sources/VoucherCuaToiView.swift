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

    private enum Dong: Identifiable {
        case khaDung(Voucher), chuaDung(VoucherCuaToi), daDung(VoucherCuaToi)
        var id: String {
            switch self {
            case .khaDung(let v): return v.id
            case .chuaDung(let v), .daDung(let v): return v.id
            }
        }
    }

    /// Lấy lần lượt từng nhóm theo thuTuNhom server (như sheet "Chọn voucher"), mỗi nhóm giữ thứ tự kéo-thả (thuTuId).
    /// Không có giỏ: "dungDuoc" = mọi voucher tài khoản dùng được; "thieuDieuKien" không có gì. Voucher đã dùng nối cuối.
    private var hienThi: [Dong] {
        let thuTuId = chon?.thuTuId ?? []
        let viTri = Dictionary(thuTuId.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        func xep(_ ds: [Dong]) -> [Dong] {
            ds.enumerated()
                .sorted { (viTri[$0.element.id] ?? Int.max, $0.offset) < (viTri[$1.element.id] ?? Int.max, $1.offset) }
                .map(\.element)
        }
        var conLai = xep((chon?.khaDung ?? []).map(Dong.khaDung) + (chon?.chuaDung ?? []).map(Dong.chuaDung))
        let nhom = (chon?.thuTuNhom.isEmpty ?? true) ? ["dungDuoc", "chuaDung"] : chon!.thuTuNhom
        var kq: [Dong] = []
        for n in nhom + ["tatCa"] {
            let lay: (Dong) -> Bool
            switch n {
            case "dungDuoc": lay = { if case .khaDung = $0 { return true } else { return false } }
            case "chuaDung": lay = { if case .chuaDung = $0 { return true } else { return false } }
            case "tatCa": lay = { _ in true }
            default: continue
            }
            kq += conLai.filter(lay)
            conLai.removeAll(where: lay)
        }
        let daCo = Set(kq.map(\.id))
        let daDung = cuaToi.filter { $0.daSuDung && !$0.chuaBatDau && !daCo.contains($0.id) }.map(Dong.daDung)
        return kq + xep(daDung)
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
            Button("Đã hiểu") {}
        } message: {
            Text(huongDan?.lyDo ?? "")
        }
    }

    /// Hàm trả về KIỂU CỤ THỂ (AnyView) thay vì gộp vào ForEach trong body — tránh Swift type-checker quá thời gian.
    private func card(for d: Dong) -> AnyView {
        switch d {
        case .khaDung(let v):
            return AnyView(VoucherTicketCard(
                ten: v.tenNgan ?? v.ten, moTa: v.moTaNgan ?? v.moTa, ma: v.ma,
                nhanGiam: v.nhanGiamGia, nhanGiamToiDa: v.nhanGiamToiDa,
                donToiThieu: v.donToiThieu,
                hienMa: false
            ))
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
            Text("Bạn chưa có voucher nào")
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
