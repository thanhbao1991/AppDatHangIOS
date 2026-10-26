import SwiftUI

/// Màn chúc mừng đầu tháng (2026-10-26): từ ngày 1 khách có quà CHỜ NHẬN theo hạng tháng trước (Bạc 10k /
/// Vàng 30k / Kim Cương 60k, dùng đến hết tháng) và — chỉ shipper — quà Top 3 tháng trước (30k/20k/10k).
/// KHÔNG tự cộng: bấm "Nhận ngay" mới cộng vào ví; chưa bấm thì lần sau mở app lại hiện. Mỗi quà 1 màn riêng.
struct QuaChucMung: Identifiable, Equatable {
    enum Loai { case hang, top }
    let loai: Loai
    let icon: String
    let tieuDe: String
    let mauHang: String
    let soXu: Double
    let ghiChu: String?
    var id: String { loai == .hang ? "hang" : "top" }
}

enum ChucMungHang {
    /// Các quà đang chờ nhận, hạng trước rồi tới Top.
    static func quaCho(_ vi: KhachHangVi?) -> [QuaChucMung] {
        var ds: [QuaChucMung] = []
        if let t = vi?.thuongHangThang, t.daNhan == false, t.soXu > 0 {
            ds.append(QuaChucMung(
                loai: .hang,
                icon: ["Kim Cương": "💎", "Vàng": "🥇", "Bạc": "🥈"][t.hang] ?? "🎉",
                tieuDe: "Bạn đạt hạng \(t.hang)\n\(tenThang(t.thangDat))",
                mauHang: t.hang, soXu: t.soXu,
                ghiChu: "Dùng đến hết \(ngayHetHan(t.hetHan))"))
        }
        if let t = vi?.thuongTopShipper, t.daNhan == false, t.soXu > 0 {
            ds.append(QuaChucMung(
                loai: .top, icon: "🏆",
                tieuDe: "Top \(t.viTri) shipper\n\(tenThang(t.thangDat))",
                mauHang: "Kim Cương", soXu: t.soXu, ghiChu: nil))
        }
        return ds
    }

    /// Gọi API nhận quà. Lỗi mạng thì thôi — màn sẽ hiện lại lần sau.
    static func nhan(_ qua: QuaChucMung) async -> Bool {
        switch qua.loai {
        case .hang: return await APIClient.shared.nhanThuongHang().success
        case .top: return await APIClient.shared.nhanThuongTop().success
        }
    }

    /// "2026-11-30T00:00:00" → "30/11"
    static func ngayHetHan(_ iso: String) -> String {
        let p = iso.prefix(10).split(separator: "-")
        return p.count == 3 ? "\(p[2])/\(p[1])" : ""
    }

    /// "10/2026" → "tháng 10"
    static func tenThang(_ thangDat: String) -> String {
        guard let m = thangDat.split(separator: "/").first, let so = Int(m) else { return "tháng trước" }
        return "tháng \(so)"
    }
}

struct ChucMungHangView: View {
    let qua: QuaChucMung
    let nhan: () async -> Void

    @State private var hien = false
    @State private var soDem: Double = 0
    @State private var dangNhan = false

    private var mau: (primary: Color, dark: Color) {
        Theme.hangColors[qua.mauHang] ?? Theme.hangColors["Thành Viên"]!
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [mau.primary, mau.dark], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            // Quầng sáng sau huy hiệu
            RadialGradient(colors: [.white.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 260)
                .offset(y: -140)
                .ignoresSafeArea()
            PhaoGiayView().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                Text(qua.icon)
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .scaleEffect(hien ? 1 : 0.2)
                    .rotationEffect(.degrees(hien ? 0 : -30))
                    .animation(.spring(response: 0.6, dampingFraction: 0.55), value: hien)

                Text("CHÚC MỪNG!")
                    .font(.system(size: 15, weight: .heavy)).tracking(3)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 24)

                Text(qua.tieuDe)
                    .font(.system(size: 30, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.top, 6)

                VStack(spacing: 6) {
                    Text("+\(formatXu(soDem))")
                        .font(.system(size: 40, weight: .heavy)).monospacedDigit()
                        .foregroundColor(.white)
                    if let ghiChu = qua.ghiChu {
                        Text(ghiChu)
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .opacity(hien ? 1 : 0)
                .offset(y: hien ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: hien)

                Spacer()

                Button {
                    dangNhan = true
                    Task { await nhan() }
                } label: {
                    Group {
                        if dangNhan { ProgressView().tint(mau.dark) } else { Text("Nhận ngay") }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(mau.dark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .disabled(dangNhan)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            hien = true
            demSo()
        }
    }

    /// Số Xu chạy từ 0 lên đủ trong ~1 giây.
    private func demSo() {
        let buoc = 30
        for i in 1...buoc {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.03) {
                soDem = (qua.soXu * Double(i) / Double(buoc) / 1000).rounded() * 1000
                if i == buoc { soDem = qua.soXu }
            }
        }
    }
}

/// Pháo giấy rơi — vẽ bằng Canvas + TimelineView, không cần thư viện ngoài.
private struct PhaoGiayView: View {
    private struct Manh {
        let x: Double, tre: Double, tocDo: Double, co: Double, mau: Color, lac: Double
    }

    private let manh: [Manh] = (0..<70).map { _ in
        Manh(x: .random(in: 0...1), tre: .random(in: 0...2.5), tocDo: .random(in: 0.12...0.25),
             co: .random(in: 6...11),
             mau: [.yellow, .white, .pink, .orange, .mint, .cyan].randomElement()!,
             lac: .random(in: 0...(2 * .pi)))
    }
    @State private var batDau = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(batDau)
                for m in manh {
                    let tt = t - m.tre
                    guard tt > 0 else { continue }
                    let y = (tt * m.tocDo).truncatingRemainder(dividingBy: 1.3) - 0.1
                    let x = m.x + sin(tt * 2 + m.lac) * 0.03
                    var c = ctx
                    c.translateBy(x: x * size.width, y: y * size.height)
                    c.rotate(by: .radians(tt * 3 + m.lac))
                    c.fill(Path(CGRect(x: -m.co / 2, y: -m.co / 4, width: m.co, height: m.co / 2)), with: .color(m.mau.opacity(0.9)))
                }
            }
        }
    }
}
