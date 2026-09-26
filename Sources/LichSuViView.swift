import SwiftUI

/// Lịch sử giao dịch ví (nạp/trừ/thưởng...) — GET /api/dat-hang/vi-giao-dich. Chỉ hiện giao dịch
/// phát sinh SAU lần xoá tài khoản gần nhất (nếu có), cùng logic ẩn dữ liệu cũ với đơn hàng/thẻ
/// tem/địa chỉ (xem KhachHangAuthService.XoaTaiKhoanAsync).
struct LichSuViView: View {
    @State private var items: [ViGiaoDich] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                fullScreenLoading()
            } else if items.isEmpty {
                Text("Chưa có giao dịch nào.").foregroundColor(Theme.textFaint).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Layout theo mẫu "Lịch sử Xu" Shopee — icon tròn lớn bên trái, tiêu đề/mô tả/giờ xếp
                // dọc, số tiền màu bên phải (không kèm số dư phụ, giống bản gốc).
                List(items) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((item.soTienThayDoi >= 0 ? Theme.success : Theme.danger).opacity(0.12))
                            Image(systemName: item.soTienThayDoi >= 0 ? "arrow.down" : "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(item.soTienThayDoi >= 0 ? Theme.success : Theme.danger)
                        }
                        .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.tenLoai).font(.system(size: 15, weight: .semibold))
                            if let ghiChu = item.ghiChu, !ghiChu.isEmpty {
                                Text(ghiChu).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                            }
                            Text(formatUtcShort(item.thoiGian)).font(.system(size: 12)).foregroundColor(Theme.textFaint)
                        }
                        Spacer()
                        Text((item.soTienThayDoi >= 0 ? "+" : "") + formatXu(item.soTienThayDoi))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(item.soTienThayDoi >= 0 ? Theme.success : Theme.danger)
                    }
                    .padding(.vertical, 4)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Lịch sử Xu")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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
