import SwiftUI

/// Tab "Voucher" — 2026-09-26: bỏ hẳn VoucherTicketCard (thiết kế "vé" riêng), đổi sang dòng chữ
/// PHẲNG (List + Divider) và thêm 3 tab TẤT CẢ/ĐANG CÓ/SẮP CÓ, khớp cấu trúc tabBar đã dùng ở
/// LichSuViView (Lịch sử Xu) và OrderStatusView (Đơn hàng).
///   - TẤT CẢ: y hệt danh sách cũ (getVoucherCuaToi — gồm cả đã dùng/sắp diễn ra), món CHƯA dùng
///     được (chuaBatDau || daSuDung) hiện MỜ ĐI để phân biệt, không ẩn hẳn.
///   - ĐANG CÓ: lọc con của TẤT CẢ, chỉ giữ voucher dùng được NGAY — không mờ (mọi dòng đều dùng
///     được nên mờ vô nghĩa).
///   - SẮP CÓ: voucher hệ thống khách CHƯA đủ điều kiện (API riêng getVoucherSapCo) — không mờ (mọi
///     dòng đều "chưa có" nên mờ vô nghĩa), kèm dòng "Cần: ..." giải thích cách mở khoá.
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
            Divider()
            Group {
                if loading {
                    fullScreenLoading()
                } else if hienThi.isEmpty {
                    // Bọc List(rỗng) thay vì Text trơn để .refreshable vẫn hoạt động (không thì khách
                    // kẹt "chưa có voucher" không vuốt xuống tải lại được).
                    List { emptyState.listRowSeparator(.hidden) }
                        .listStyle(.plain)
                        .refreshable { await load() }
                } else {
                    List(hienThi) { v in
                        voucherRow(v)
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
        }
        .task { await load() }
    }

    private var tabBar: some View {
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
        .background(Color(.systemBackground))
    }

    /// Mượn lại chi tiết đẹp NHẤT của VoucherTicketCard cũ — khối MÀU bên trái chứa số giảm to/đậm —
    /// nhưng chỉ làm 1 chip màu bo góc (không phải khối bo góc cả card + dashed divider + viền/bóng
    /// đổ quanh cả dòng). Thiếu khối này số giảm chìm nghỉm thành chữ nhỏ bên phải, không giống bản
    /// cũ (phản hồi thực tế 2026-09-26 kèm ảnh so sánh).
    private func voucherRow(_ v: VoucherCuaToi) -> some View {
        // Chỉ mờ ở tab TẤT CẢ — ĐANG CÓ/SẮP CÓ mỗi tab đã tự thân đồng nhất 1 trạng thái (toàn dùng
        // được / toàn chưa mở khoá), mờ thêm không có ý nghĩa phân biệt gì.
        let mo = tab == .tatCa && (v.chuaBatDau || v.daSuDung)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(v.nhanGiamGia)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let nhanGiamToiDa = v.nhanGiamToiDa {
                    Text(nhanGiamToiDa)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 76)
            .padding(.vertical, 10)
            .background(mo ? AnyShapeStyle(Theme.textFaint) : AnyShapeStyle(Theme.primaryGradient))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 8) {
                    Text(v.ten).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                    Spacer(minLength: 4)
                    trangThaiBadge(v)
                }
                if let moTa = v.moTa, !moTa.isEmpty {
                    Text(moTa).font(.system(size: 12)).foregroundColor(Theme.textMuted).lineLimit(2)
                }
                if let lyDo = v.lyDoChuaKhaDung {
                    Text("Cần: \(lyDo)").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.warning)
                }
                if let nhanSoLan = v.nhanSoLan {
                    Text("🔁 \(nhanSoLan)").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.primary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill").font(.system(size: 10)).foregroundColor(Theme.primary)
                    Text(v.ma).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Theme.primary)
                    if let donToiThieu = v.donToiThieu, donToiThieu > 0 {
                        Text("· Đơn từ \(formatTien(donToiThieu))").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .opacity(mo ? 0.6 : 1)
    }

    @ViewBuilder
    private func trangThaiBadge(_ v: VoucherCuaToi) -> some View {
        if v.daSuDung {
            Text("Đã dùng").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textFaint)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Theme.divider))
        } else if let nhanSapDienRa = v.nhanSapDienRa {
            Text(nhanSapDienRa).font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Theme.primary))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket").font(.system(size: 40)).foregroundColor(Theme.textFaint)
            Text(tab == .sapCo ? "Chưa có ưu đãi nào sắp mở khoá." : "Bạn chưa có voucher nào")
                .font(.system(size: 14)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private func load() async {
        async let vouchersTask = APIClient.shared.getVoucherCuaToi()
        async let sapCoTask = APIClient.shared.getVoucherSapCo()
        vouchers = await vouchersTask
        voucherSapCo = await sapCoTask
        loading = false
    }
}
