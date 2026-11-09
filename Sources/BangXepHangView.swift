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

/// Thiết kế lại 09/11/2026 theo mẫu chủ quán gửi: nền kem ấm, bục 3D vàng/bạc/đồng, mỗi người top 3 có vương miện
/// riêng, tên trên nhãn trắng + Xu trên nhãn xanh đậm; hạng 4–10 trong thẻ trắng, avatar màu pastel, người có quà
/// (hạng 4) tô vàng; cuối màn là lời cảm ơn (câu chữ từ backend).
struct BangXepHangView: View {
    @Environment(\.dismiss) private var dismiss
    // 09/11/2026: hiện ngay bảng lần trước (BoNhoTam), tải lại rồi thay vào.
    @State private var bang: BangXepHang? = BoNhoTam.bangXepHang
    @State private var loi = false

    private static let kem = Color(red: 1.0, green: 0.976, blue: 0.937)
    private static let kemDam = Color(red: 0.984, green: 0.937, blue: 0.851)
    private static let xanhDam = Color(red: 0.11, green: 0.16, blue: 0.29)
    private static let nau = Color(red: 0.55, green: 0.38, blue: 0.14)

    var body: some View {
        NavigationStack {
            Group {
                if let bang {
                    ScrollView {
                        VStack(spacing: 18) {
                            if bang.dong.isEmpty {
                                Text("Chưa có ai trong bảng tháng này.")
                                    .foregroundColor(.secondary).padding(.vertical, 60)
                            } else {
                                buc(bang.dong.filter { $0.viTri <= 3 })
                                let conLai = bang.dong.filter { $0.viTri > 3 }
                                if !conLai.isEmpty {
                                    VStack(spacing: 8) {
                                        ForEach(conLai) { d in dongView(d) }
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(Color.white.opacity(0.85))
                                            .shadow(color: Self.nau.opacity(0.10), radius: 12, y: 4)
                                    )
                                }
                                camOn
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
                    }
                    .background(
                        LinearGradient(colors: [Self.kem, Self.kemDam], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                    )
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
        if let b = await APIClient.shared.getBangXepHang() {
            bang = b
            BoNhoTam.bangXepHang = b
        } else if bang == nil { loi = true } // đang hiện bảng cũ thì giữ, không báo lỗi
    }

    // MARK: - Màu huy chương (sáng → đậm cho khối 3D)

    static func mauHuyChuong(_ viTri: Int) -> (sang: Color, dam: Color) {
        switch viTri {
        case 1: return (Color(red: 1.0, green: 0.86, blue: 0.40), Color(red: 0.90, green: 0.62, blue: 0.10))
        case 2: return (Color(red: 0.90, green: 0.92, blue: 0.95), Color(red: 0.62, green: 0.66, blue: 0.73))
        default: return (Color(red: 0.96, green: 0.72, blue: 0.55), Color(red: 0.76, green: 0.45, blue: 0.27))
        }
    }

    /// Màu pastel cố định theo chữ cái — mỗi người một màu, không đổi giữa các lần mở.
    static func mauPastel(_ ten: String) -> Color {
        let bang: [Color] = [
            Color(red: 0.80, green: 0.88, blue: 1.00), Color(red: 0.88, green: 0.84, blue: 0.98),
            Color(red: 0.80, green: 0.94, blue: 0.86), Color(red: 1.00, green: 0.84, blue: 0.84),
            Color(red: 0.80, green: 0.94, blue: 0.94), Color(red: 1.00, green: 0.90, blue: 0.78),
        ]
        let so = ten.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return bang[so % bang.count]
    }

    /// Chữ cái đầu cho ô tròn; tên chỉ còn SĐT che ("•••• 6947") thì dùng 2 số cuối.
    static func kyTuDaiDien(_ ten: String) -> String {
        let t = ten.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("•") { return String(t.filter(\.isNumber).suffix(2)) }
        return t.first.map { String($0).uppercased() } ?? "?"
    }

    /// Dòng của chính mình backend trả tên "Bạn" → hiện hình người thay vì chữ "B".
    @ViewBuilder
    private func daiDien(_ d: BangXepHangDong, co: CGFloat, mau: Color) -> some View {
        if d.laBan {
            Image(systemName: "person.fill").font(.system(size: co * 0.95, weight: .bold)).foregroundColor(mau)
        } else {
            Text(Self.kyTuDaiDien(d.ten))
                .font(.system(size: co, weight: .heavy, design: .rounded)).foregroundColor(mau)
        }
    }

    // MARK: - Bục top 3 (2 · 1 · 3)

    private func buc(_ top: [BangXepHangDong]) -> some View {
        let theoViTri = Dictionary(top.map { ($0.viTri, $0) }, uniquingKeysWith: { a, _ in a })
        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach([2, 1, 3], id: \.self) { v in
                    if let d = theoViTri[v] { cotBuc(d) } else { Color.clear.frame(maxWidth: .infinity) }
                }
            }
            // Bệ trắng dưới chân bục
            Capsule()
                .fill(LinearGradient(colors: [.white, Self.kemDam], startPoint: .top, endPoint: .bottom))
                .frame(height: 16)
                .shadow(color: Self.nau.opacity(0.15), radius: 6, y: 3)
                .padding(.horizontal, -6)
        }
        .padding(.top, 8)
    }

    private func cotBuc(_ d: BangXepHangDong) -> some View {
        let (sang, dam) = Self.mauHuyChuong(d.viTri)
        let laMot = d.viTri == 1
        let co: CGFloat = laMot ? 86 : 66
        return VStack(spacing: 0) {
            // Vương miện + vòng huy chương (+ cành nguyệt quế cho hạng 1 trên iOS 17)
            ZStack {
                if laMot { nguyetQue(mau: dam, co: co) }
                VStack(spacing: -8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: laMot ? 28 : 20))
                        .foregroundStyle(LinearGradient(colors: [sang, dam], startPoint: .top, endPoint: .bottom))
                        .shadow(color: dam.opacity(0.4), radius: 2, y: 1)
                        .zIndex(1)
                    Circle()
                        .fill(LinearGradient(colors: [.white, sang.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .overlay(daiDien(d, co: co * 0.36, mau: dam))
                        .padding(5)
                        .background(Circle().fill(LinearGradient(colors: [sang, dam], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .frame(width: co, height: co)
                        .shadow(color: dam.opacity(0.35), radius: 6, y: 3)
                }
            }
            // Nhãn tên (trắng) + nhãn Xu (xanh đậm, viền màu huy chương)
            VStack(spacing: -4) {
                Text(d.ten)
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Self.xanhDam)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(.white).shadow(color: Self.nau.opacity(0.12), radius: 3, y: 1))
                    .zIndex(1)
                Text(giaTri(d.xu, soDon: d.soDon))
                    .font(.system(size: laMot ? 16 : 14, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Self.xanhDam))
                    .overlay(Capsule().stroke(sang, lineWidth: 1.5))
            }
            .padding(.top, 6).padding(.horizontal, 4)
            .zIndex(1)
            // Khối bục 3D: mặt trên sáng, thân chuyển đậm, số lớn trắng, quà Top ở dưới số
            VStack(spacing: 4) {
                Text("\(d.viTri)")
                    .font(.system(size: laMot ? 44 : 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: dam.opacity(0.8), radius: 1, y: 2)
                if d.thuongXu > 0 {
                    Text("+\(formatXu(d.thuongXu))")
                        .font(.system(size: 10, weight: .heavy)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundColor(dam)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.9)))
                }
            }
            .padding(.top, 14).padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: laMot ? 124 : (d.viTri == 2 ? 96 : 80), alignment: .top)
            .background(
                ZStack(alignment: .top) {
                    LinearGradient(colors: [sang, dam], startPoint: .top, endPoint: .bottom)
                    // mặt trên của khối
                    LinearGradient(colors: [.white.opacity(0.7), sang.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 10)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.top, -10)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func nguyetQue(mau: Color, co: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            HStack(spacing: co * 0.55) {
                Image(systemName: "laurel.leading")
                Image(systemName: "laurel.trailing")
            }
            .font(.system(size: co * 0.62, weight: .regular))
            .foregroundStyle(mau.opacity(0.8))
            .offset(y: 10)
        }
    }

    // MARK: - Hạng 4–10

    private func dongView(_ d: BangXepHangDong) -> some View {
        let coQua = d.thuongXu > 0
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                if coQua {
                    Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.15))
                }
                Text("\(d.viTri)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundColor(Self.xanhDam)
            }
            .frame(width: 26)
            Circle()
                .fill(Self.mauPastel(d.ten))
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .overlay(daiDien(d, co: 16, mau: Self.xanhDam.opacity(0.85)))
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(d.ten)
                    .font(.system(size: 15, weight: d.laBan ? .heavy : .semibold)).foregroundColor(Self.xanhDam)
                    .lineLimit(1)
                if coQua {
                    Text("+\(formatXu(d.thuongXu))")
                        .font(.system(size: 11, weight: .bold)).monospacedDigit()
                        .foregroundColor(Self.nau)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 1.0, green: 0.88, blue: 0.62)))
                }
            }
            Spacer()
            Text(giaTri(d.xu, soDon: d.soDon))
                .font(.system(size: 15, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundColor(Self.xanhDam)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(coQua
                      ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.95, blue: 0.82), Color(red: 1.0, green: 0.98, blue: 0.92)],
                                                     startPoint: .leading, endPoint: .trailing))
                      : AnyShapeStyle(Color.white))
        )
        // Chủ quán 09/11/2026: hạng có quà (top 4) không cần khung viền — chỉ tô nền vàng nhạt.
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(d.laBan && !coQua ? Theme.primary : Color.black.opacity(coQua ? 0 : 0.04),
                        lineWidth: d.laBan && !coQua ? 1.5 : 1)
        )
    }

    // MARK: - Lời cảm ơn cuối màn

    private var camOn: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.system(size: 10))
                Text(NoiDung.text("bxhCamOn"))
                    .font(.system(size: 22, weight: .semibold, design: .serif)).italic()
                Image(systemName: "heart.fill").font(.system(size: 10))
            }
            .foregroundColor(Self.nau)
            Text(NoiDung.text("bxhCamOnPhu"))
                .font(.system(size: 13)).foregroundColor(Self.nau.opacity(0.8))
        }
        .padding(.top, 6)
    }

    private func giaTri(_ xu: Double?, soDon: Int) -> String {
        if let xu, xu > 0 { return formatXu(xu) }
        return "\(soDon) đơn"
    }
}
