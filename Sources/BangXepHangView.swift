import SwiftUI

/// Bảng xếp hạng công khai tháng này (08/11/2026) — mở khi chạm nhãn "Top N"/"Top ?" trên thẻ hạng. Shipper xem bảng
/// shipper, khách xem bảng khách (xếp theo Xu sẽ nhận ngày 1 tháng sau). Tên người khác đã che ở backend.
struct BangXepHang: Decodable {
    let tieuDe: String
    let moTa: String
    let dong: [BangXepHangDong]
    let viTriCuaBan: Int?
    let soDonCuaBan: Int
    let xuCuaBan: Double?
    let conLaiDeVuot: Double
    let lyDo: String?
}

struct BangXepHangDong: Decodable, Identifiable {
    let viTri: Int
    let ten: String
    let soDon: Int
    let xu: Double?
    let thuongXu: Double
    let laBan: Bool
    var id: String { "\(viTri)-\(ten)" }
}

struct BangXepHangView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bang: BangXepHang?
    @State private var loi = false

    var body: some View {
        NavigationStack {
            Group {
                if let bang {
                    List {
                        Section {
                            Text(bang.moTa)
                                .font(.system(size: 13)).foregroundColor(.secondary)
                                .listRowBackground(Color.clear)
                        }
                        Section {
                            if bang.dong.isEmpty {
                                Text("Chưa có ai trong bảng tháng này.").foregroundColor(.secondary)
                            }
                            ForEach(bang.dong) { d in dongView(d) }
                        }
                        Section { cuaBan(bang) }
                    }
                } else if loi {
                    VStack(spacing: 12) {
                        Text("Chưa tải được bảng xếp hạng.").foregroundColor(.secondary)
                        Button("Thử lại") { Task { await tai() } }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(bang?.tieuDe ?? "Bảng xếp hạng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }
        .task { await tai() }
    }

    private func tai() async {
        loi = false
        if let b = await APIClient.shared.getBangXepHang() { bang = b } else { loi = true }
    }

    private func huyHieu(_ viTri: Int) -> String {
        switch viTri { case 1: return "🥇"; case 2: return "🥈"; case 3: return "🥉"; default: return "\(viTri)" }
    }

    private func dongView(_ d: BangXepHangDong) -> some View {
        HStack(spacing: 12) {
            Text(huyHieu(d.viTri))
                .font(.system(size: d.viTri <= 3 ? 24 : 15, weight: .bold))
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.ten).font(.system(size: 15, weight: d.laBan ? .heavy : .semibold))
                if d.thuongXu > 0 {
                    Text("Thưởng \(formatXu(d.thuongXu))")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.primary)
                }
            }
            Spacer()
            Text(giaTri(d.xu, soDon: d.soDon))
                .font(.system(size: 14, weight: .bold)).monospacedDigit()
        }
        .padding(.vertical, 2)
        .listRowBackground(d.laBan ? Theme.primary.opacity(0.12) : Color(.secondarySystemGroupedBackground))
    }

    private func giaTri(_ xu: Double?, soDon: Int) -> String {
        if let xu, xu > 0 { return formatXu(xu) }
        return "\(soDon) đơn"
    }

    @ViewBuilder
    private func cuaBan(_ b: BangXepHang) -> some View {
        if let viTri = b.viTriCuaBan {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bạn đang hạng \(viTri)").font(.system(size: 15, weight: .heavy))
                Text(giaTri(b.xuCuaBan, soDon: b.soDonCuaBan)).font(.system(size: 13)).foregroundColor(.secondary)
                if b.conLaiDeVuot > 0 {
                    Text("Đặt thêm \(formatTien(b.conLaiDeVuot)) qua app để vượt lên.")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                } else if viTri == 1 {
                    Text("Bạn đang dẫn đầu 🎉").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                }
            }
        } else if let lyDo = b.lyDo {
            Text(lyDo).font(.system(size: 13)).foregroundColor(.secondary)
        }
    }

    private func formatTien(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = "."; f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? "\(Int(v))") + "đ"
    }
}
