import SwiftUI

/// Lịch sử giao dịch ví (nạp/trừ/thưởng...) — GET /api/dat-hang/vi-giao-dich. Chỉ hiện giao dịch
/// phát sinh SAU lần xoá tài khoản gần nhất (nếu có), cùng logic ẩn dữ liệu cũ với đơn hàng/thẻ
/// tem/địa chỉ (xem KhachHangAuthService.XoaTaiKhoanAsync).
struct LichSuViView: View {
    /// 3 tab lọc theo mẫu "Shopee Xu" — LỊCH SỬ (tất cả), ĐÃ NHẬN (cộng), ĐÃ DÙNG (trừ). Lọc thuần
    /// client-side trên `items` đã tải sẵn, không gọi lại API.
    private enum LocTab: String, CaseIterable {
        case tatCa = "Tất cả"
        case daNhan = "Đã nhận"
        case daDung = "Đã dùng"
    }

    @State private var items: [ViGiaoDich] = []
    @State private var loading = true
    @State private var tab: LocTab = .tatCa

    private var filteredItems: [ViGiaoDich] {
        switch tab {
        case .tatCa: return items
        case .daNhan: return items.filter { $0.soTienThayDoi >= 0 }
        case .daDung: return items.filter { $0.soTienThayDoi < 0 }
        }
    }

    // Thiết kế lại 09/11/2026 theo bộ khung TK: thanh lọc viên thuốc + mỗi giao dịch một thẻ.
    var body: some View {
        VStack(spacing: 0) {
            TKThanhLoc(cacMuc: LocTab.allCases, nhan: { $0.rawValue }, chon: $tab)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
            Group {
                if loading {
                    fullScreenLoading()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if filteredItems.isEmpty {
                                TKTrong(icon: "tray", chu: "Chưa có giao dịch nào.")
                            }
                            ForEach(filteredItems) { item in
                                HStack(spacing: 12) {
                                    rowIcon(item)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.tenLoai).font(.system(size: 15, weight: .semibold))
                                        if let ghiChu = item.ghiChu, !ghiChu.isEmpty {
                                            Text(ghiChu).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                                        }
                                        Text(formatUtcShort(item.thoiGian)).font(.system(size: 12)).foregroundColor(Theme.textFaint)
                                    }
                                    Spacer(minLength: 8)
                                    Text((item.soTienThayDoi >= 0 ? "+" : "") + formatXu(item.soTienThayDoi))
                                        .font(.system(size: 16, weight: .heavy, design: .rounded)).monospacedDigit()
                                        .foregroundColor(item.soTienThayDoi >= 0 ? Theme.success : Theme.danger)
                                }
                                .tkThe(dem: 14)
                            }
                        }
                        .tkManHinh()
                    }
                    .refreshable { await load() }
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("Lịch sử Xu")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// Icon từng dòng — icon Xu khi CỘNG (thưởng/điểm danh...), ảnh món đầu tiên của hoá đơn khi TRỪ
    /// (thanh toán đơn, giống Shopee hiện ảnh sản phẩm đã mua); trừ mà không có ảnh (hoaDonId null,
    /// vd điều chỉnh thủ công hiếm gặp) thì rơi về mũi tên như cũ.
    @ViewBuilder
    private func rowIcon(_ item: ViGiaoDich) -> some View {
        if item.soTienThayDoi >= 0 {
            // 09/11/2026: ô icon TK thay icon đồng xu ảnh (chủ quán: lạc lõng).
            TKIcon(ten: "arrow.down.left", mau: Theme.success, co: 44)
        } else if let hinhAnh = item.hinhAnhSanPhamDauTien, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        } else {
            TKIcon(ten: "arrow.up.right", mau: Theme.danger, co: 44)
        }
    }

    /// FIX 2026-09-23 (lệch giờ +7 phát hiện qua ảnh chụp thật): ViGiaoDich.ThoiGian là
    /// VietnamTime.Now (đã LÀ giờ VN, Kind=Unspecified, KHÔNG PHẢI UTC thật — xem
    /// KhachHangViService/KhachHangCrudService) — bản cũ ép "Z" rồi quy đổi Asia/Ho_Chi_Minh làm
    /// CỘNG THÊM +7 giờ nữa (double-shift). Đổi sang parse THẲNG bằng chính giờ VN, không quy đổi gì
    /// — cùng cách formatThongBaoTime (ThongBaoView.swift) đã làm đúng cho NgayTao thông báo.
    private func formatUtcShort(_ iso: String) -> String {
        let inF = DateFormatter()
        inF.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        inF.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        inF.locale = Locale(identifier: "en_US_POSIX")
        guard let date = inF.date(from: String(iso.prefix(19))) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "HH:mm dd/MM/yyyy"
        out.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return out.string(from: date)
    }

    private func load() async {
        items = await APIClient.shared.getLichSuVi()
        loading = false
    }
}
