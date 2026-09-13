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
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                Text("Chưa có giao dịch nào.").foregroundColor(Theme.textFaint).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.soTienThayDoi >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundColor(item.soTienThayDoi >= 0 ? Theme.success : Theme.danger)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.tenLoai).font(.system(size: 14, weight: .bold))
                            if let ghiChu = item.ghiChu, !ghiChu.isEmpty {
                                Text(ghiChu).font(.system(size: 12)).foregroundColor(Theme.textMuted)
                            }
                            Text(formatUtcShort(item.thoiGian)).font(.system(size: 11)).foregroundColor(Theme.textFaint)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text((item.soTienThayDoi >= 0 ? "+" : "") + formatXu(item.soTienThayDoi))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(item.soTienThayDoi >= 0 ? Theme.success : Theme.danger)
                            Text("Số dư: \(formatXu(item.soDuSau))").font(.system(size: 11)).foregroundColor(Theme.textFaint)
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Lịch sử Xu")
        .navigationBarTitleDisplayMode(.inline)
        .brandNavBar()
        .task { await load() }
    }

    /// Backend trả DateTime "yyyy-MM-ddTHH:mm:ss.fffffff" (Kind=Unspecified nhưng thực chất UTC) —
    /// ép hậu tố "Z" trước khi parse để không bị hiểu nhầm thành giờ máy.
    private func formatUtcShort(_ iso: String) -> String {
        let trimmed = String(iso.prefix(19)) + "Z"
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: trimmed) else { return iso }
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
