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

/// Khối bục: chỉ bo 2 góc trên (UnevenRoundedRectangle cần iOS 17, app còn hỗ trợ iOS 16).
private struct BoGocTren: Shape {
    let r: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: r, height: r)).cgPath)
    }
}

struct BangXepHangView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bang: BangXepHang?
    @State private var loi = false

    var body: some View {
        NavigationStack {
            Group {
                if let bang {
                    ScrollView {
                        VStack(spacing: 16) {
                            if bang.dong.isEmpty {
                                Text("Chưa có ai trong bảng tháng này.")
                                    .foregroundColor(.secondary).padding(.vertical, 40)
                            } else {
                                buc(bang.dong.filter { $0.viTri <= 3 })
                                let conLai = bang.dong.filter { $0.viTri > 3 }
                                if !conLai.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(Array(conLai.enumerated()), id: \.element.id) { i, d in
                                            if i > 0 { Divider().padding(.leading, 62) }
                                            dongView(d)
                                        }
                                    }
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            Text(bang.moTa)
                                .font(.system(size: 12)).foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
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

    // MARK: - Bục top 3 (2 · 1 · 3)

    static func mauHuyChuong(_ viTri: Int) -> Color {
        switch viTri {
        case 1: return Color(red: 0.98, green: 0.74, blue: 0.16)
        case 2: return Color(red: 0.62, green: 0.66, blue: 0.72)
        default: return Color(red: 0.80, green: 0.50, blue: 0.27)
        }
    }

    /// Chữ cái đầu cho ô tròn; tên chỉ còn SĐT che ("•••• 6947") thì dùng 2 số cuối.
    static func kyTuDaiDien(_ ten: String) -> String {
        let t = ten.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("•") { return String(t.filter(\.isNumber).suffix(2)) }
        return t.first.map { String($0).uppercased() } ?? "?"
    }

    private func buc(_ top: [BangXepHangDong]) -> some View {
        let theoViTri = Dictionary(top.map { ($0.viTri, $0) }, uniquingKeysWith: { a, _ in a })
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach([2, 1, 3], id: \.self) { v in
                if let d = theoViTri[v] { cotBuc(d) } else { Color.clear.frame(maxWidth: .infinity) }
            }
        }
        .padding(.top, 8)
    }

    private func cotBuc(_ d: BangXepHangDong) -> some View {
        let mau = Self.mauHuyChuong(d.viTri)
        let laMot = d.viTri == 1
        let co: CGFloat = laMot ? 72 : 58
        return VStack(spacing: 6) {
            ZStack(alignment: .top) {
                Circle()
                    .fill(LinearGradient(colors: [mau.opacity(0.35), mau.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(mau, lineWidth: 3))
                    .overlay(Text(Self.kyTuDaiDien(d.ten))
                        .font(.system(size: co * 0.38, weight: .heavy, design: .rounded))
                        .foregroundColor(mau.opacity(0.95)))
                    .frame(width: co, height: co)
                    .padding(.top, laMot ? 16 : 0)
                if laMot {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22)).foregroundColor(mau)
                        .shadow(color: mau.opacity(0.4), radius: 3, y: 1)
                        .offset(y: -6)
                }
            }
            Text(d.ten)
                .font(.system(size: 13, weight: d.laBan ? .heavy : .semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(giaTri(d.xu, soDon: d.soDon))
                .font(.system(size: laMot ? 15 : 13, weight: .bold)).monospacedDigit()
                .foregroundColor(Theme.primaryDark)
            ZStack(alignment: .top) {
                BoGocTren(r: 12)
                    .fill(LinearGradient(colors: [mau, mau.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 6) {
                    Text("\(d.viTri)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    if d.thuongXu > 0 {
                        Text("+\(formatXu(d.thuongXu))")
                            .font(.system(size: 10, weight: .bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundColor(mau)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(.white))
                    }
                }
                .padding(.top, 8).padding(.horizontal, 4)
            }
            .frame(height: laMot ? 110 : (d.viTri == 2 ? 86 : 70))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hạng 4–10

    private func dongView(_ d: BangXepHangDong) -> some View {
        HStack(spacing: 12) {
            Text("\(d.viTri)")
                .font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 20)
            Circle()
                .fill(Theme.primary.opacity(0.12))
                .overlay(Text(Self.kyTuDaiDien(d.ten))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primary))
                .frame(width: 34, height: 34)
            Text(d.ten).font(.system(size: 15, weight: d.laBan ? .heavy : .medium)).lineLimit(1)
            Spacer()
            Text(giaTri(d.xu, soDon: d.soDon))
                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(d.laBan ? Theme.primary.opacity(0.10) : Color.clear)
    }

    private func giaTri(_ xu: Double?, soDon: Int) -> String {
        if let xu, xu > 0 { return formatXu(xu) }
        return "\(soDon) đơn"
    }
}
