import SwiftUI

/// Bộ khung giao diện chung cho tab Tài khoản và mọi màn mở từ đó (09/11/2026, chủ quán: "style lại toàn bộ tab tài
/// khoản và các màn mở từ đó để đồng bộ"). Cùng ngôn ngữ với thẻ hạng/bảng xếp hạng mới: thẻ trắng bo 18 có bóng nhẹ,
/// tiêu đề có ô icon tô màu, dòng điều hướng kiểu Cài đặt. Màu chủ đạo vẫn là Theme.primary (theo hạng/dịp lễ).
enum TK {
    static let bo: CGFloat = 18
    static let khoangCach: CGFloat = 14
}

extension View {
    /// Thẻ trắng bo góc có bóng nhẹ — khối cơ bản của tab Tài khoản.
    func tkThe(dem: CGFloat = 16) -> some View {
        self
            .padding(dem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TK.bo, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
    }

    /// Nền + lề chung cho màn con (ScrollView chứa các thẻ).
    func tkManHinh() -> some View {
        self
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// Ô icon vuông bo góc tô màu nhạt (kiểu Cài đặt iOS).
struct TKIcon: View {
    let ten: String
    var mau: Color = Theme.primary
    var co: CGFloat = 30

    var body: some View {
        Image(systemName: ten)
            .font(.system(size: co * 0.48, weight: .semibold))
            .foregroundColor(mau)
            .frame(width: co, height: co)
            .background(RoundedRectangle(cornerRadius: co * 0.3, style: .continuous).fill(mau.opacity(0.13)))
    }
}

/// Tiêu đề thẻ: ô icon + chữ đậm, bên phải tuỳ chọn (nút +, link…).
struct TKTieuDe<Phai: View>: View {
    let icon: String
    var mau: Color = Theme.primary
    let tieuDe: String
    @ViewBuilder var phai: () -> Phai

    var body: some View {
        HStack(spacing: 10) {
            TKIcon(ten: icon, mau: mau)
            Text(tieuDe).font(.system(size: 16, weight: .bold))
            Spacer(minLength: 8)
            phai()
        }
    }
}

extension TKTieuDe where Phai == EmptyView {
    init(icon: String, mau: Color = Theme.primary, tieuDe: String) {
        self.init(icon: icon, mau: mau, tieuDe: tieuDe) { EmptyView() }
    }
}

/// Một dòng điều hướng: ô icon + tiêu đề (+ phụ) + giá trị bên phải + mũi tên.
struct TKDong: View {
    let icon: String
    var mau: Color = Theme.primary
    let tieuDe: String
    var phu: String? = nil
    var giaTri: String? = nil
    var muiTen = true
    var mauChu: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            TKIcon(ten: icon, mau: mau)
            VStack(alignment: .leading, spacing: 2) {
                Text(tieuDe).font(.system(size: 15, weight: .semibold)).foregroundColor(mauChu)
                if let phu {
                    Text(phu).font(.system(size: 12)).foregroundColor(Theme.textMuted).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let giaTri {
                Text(giaTri).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.textMuted)
            }
            if muiTen {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textFaint)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Đường kẻ giữa các dòng trong thẻ — thụt vào ngang ô icon.
struct TKKe: View {
    var body: some View { Divider().padding(.leading, 42) }
}

/// Ô nhập liệu cùng kiểu: nền xám nhạt bo góc, không viền.
struct TKONhap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.bg))
            .tint(Theme.primary)
    }
}

extension View {
    func tkONhap() -> some View { modifier(TKONhap()) }
}

/// Thanh lọc dạng viên thuốc (thay tab gạch chân) — dùng ở Lịch sử Xu.
struct TKThanhLoc<T: Hashable>: View {
    let cacMuc: [T]
    let nhan: (T) -> String
    @Binding var chon: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(cacMuc, id: \.self) { m in
                Button { withAnimation(.easeInOut(duration: 0.15)) { chon = m } } label: {
                    Text(nhan(m))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(chon == m ? .white : Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(chon == m ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Color.clear)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 6, y: 2))
    }
}

/// Phần đầu thẻ Rương Xu (09/11/2026): ảnh rương (Assets RuongXu) + số Xu tháng này. Bình thường ĐỨNG YÊN; chỉ khi số Xu
/// LỚN HƠN lần cuối khách xem (lưu máy theo khách + tháng) mới chạy hiệu ứng: vài đồng Xu bay từ trên, xoay, rơi vào miệng
/// rương rồi thu nhỏ CHUI vào trong (lấp sau thành trước), rương nảy + lóe sáng mỗi đồng, số đếm chạy từ số cũ lên số mới,
/// hiện "+N Xu" bay lên. Xem xong lưu mốc mới. Tháng mới: mốc cũ thuộc tháng trước nên tính từ 0.
struct RuongXuDau<Phai: View>: View {
    let xu: Double
    /// Nút bên phải hàng tiêu đề (Top N — thẻ hạng đã bỏ 09/11/2026).
    var tieuDePhai: AnyView? = nil
    let onInfo: () -> Void
    @ViewBuilder var duoiSo: () -> Phai

    @State private var soHienThi: Double = 0
    @State private var dangChay = false
    @State private var batDau: Date?
    @State private var soXuBay = 0
    @State private var cong: Double = 0
    /// Số Xu đổi TRONG LÚC hiệu ứng đang chạy (vd đổi tài khoản → ví tải 2 lần liên tiếp) — trước 10/11/2026 bị bỏ qua nên
    /// rương kẹt số cũ (7.400 trong khi app+quầy = 7.950), vuốt tải lại cũng không đổi vì `xu` không đổi nữa.
    @State private var xuCho: Double?

    // Kiểu generic không có static stored property — dùng computed.
    private static var cachXu: Double { 0.22 }   // giây giữa 2 đồng
    private static var roiMat: Double { 0.55 }   // giây 1 đồng rơi

    private var khoa: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        let c = cal.dateComponents([.year, .month], from: Date())
        return "ruongXu.daXem.\(Prefs.khachHangId ?? "?").\(c.year ?? 0)-\(c.month ?? 0)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ruong.frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Text(NoiDung.text("ruongXuTieuDe"))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMuted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    if let tieuDePhai { tieuDePhai }
                }
                Button(action: onInfo) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            SoXuChay(value: soHienThi)
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                            Text(" Xu").font(.system(size: 15, weight: .bold))
                        }
                        .monospacedDigit().foregroundColor(Theme.xuTangChu)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textFaint)
                    }
                    .overlay(alignment: .topTrailing) {
                        if dangChay && cong > 0 {
                            Text("+\(SoDuCard.so(cong))")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.success)
                                .offset(x: 10, y: -14)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                        removal: .move(edge: .top).combined(with: .opacity)))
                        }
                    }
                }
                .buttonStyle(.plain)
                duoiSo()
            }
            // Giãn hết bề ngang để nhãn Top (tieuDePhai) sát mép phải thẻ, thẳng hàng ô "Đặt qua app".
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: kiemTra)
        .onChange(of: xu) { _ in kiemTra() }
    }

    private var ruong: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !dangChay)) { ctx in
            let tg = batDau.map { ctx.date.timeIntervalSince($0) } ?? 99
            GeometryReader { geo in
                let w = geo.size.width
                let nay = doNay(tg)
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4).opacity(0.6 * nay + 0.12), .clear],
                                             center: .center, startRadius: 0, endRadius: w * 0.55))
                    // Thân rương (cả ảnh) — xu vẽ ĐÈ lên, rồi phần nửa dưới ảnh (thành trước) vẽ đè lại xu → xu như chui vào trong.
                    anhRuong(w, nay: nay)
                    ForEach(0..<soXuBay, id: \.self) { i in
                        let p = (tg - Double(i) * Self.cachXu) / Self.roiMat
                        if p > 0 && p < 1 {
                            Theme.xuIcon(w * 0.22 * (1 - 0.45 * max(0, (p - 0.7) / 0.3)))
                                .rotation3DEffect(.degrees(p * 540), axis: (x: 0, y: 1, z: 0))
                                .offset(x: CGFloat(i % 3 - 1) * w * 0.07 * (1 - p),
                                        y: -w * 0.62 + CGFloat(p * p) * w * 0.74)
                                .opacity(p < 0.9 ? 1 : (1 - p) / 0.1)
                        }
                    }
                    anhRuong(w, nay: nay)
                        .mask(alignment: .bottom) {
                            Rectangle().frame(height: w * 0.5)   // thành trước rương (từ ổ khoá xuống)
                        }
                }
                .frame(width: w, height: geo.size.height)
            }
        }
    }

    private func anhRuong(_ w: CGFloat, nay: Double) -> some View {
        Image("RuongXu")
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: w * 0.92, height: w * 0.92)
            .scaleEffect(x: 1 + 0.04 * nay, y: 1 - 0.05 * nay, anchor: .bottom)
            .offset(y: w * 0.04)
            .frame(width: w, height: w)
    }

    /// Nảy ngắn mỗi lần 1 đồng chạm miệng rương (≈ 85% đường rơi).
    private func doNay(_ tg: Double) -> Double {
        guard dangChay else { return 0 }
        for i in 0..<soXuBay {
            let cham = Double(i) * Self.cachXu + Self.roiMat * 0.85
            let d = tg - cham
            if d >= 0 && d < 0.16 { return sin(d / 0.16 * .pi) }
        }
        return 0
    }

    private func kiemTra() {
        let ud = UserDefaults.standard
        let cu = ud.object(forKey: khoa) as? Double ?? 0
        if dangChay {
            // Đang chạy hiệu ứng: nhớ số mới, chạy xong sẽ áp (không bỏ qua như trước).
            xuCho = xu
            ud.set(xu, forKey: khoa)
            return
        }
        guard xu > cu else {
            soHienThi = xu
            if xu < cu { ud.set(xu, forKey: khoa) }
            return
        }
        soHienThi = cu
        cong = xu - cu
        soXuBay = min(6, max(3, Int(cong / 2000) + 2))
        let tongTg = Double(soXuBay - 1) * Self.cachXu + Self.roiMat + 0.3
        ud.set(xu, forKey: khoa)
        // Chờ màn vào hẳn rồi mới chạy cho khách kịp nhìn.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            batDau = Date()
            withAnimation(.spring(response: 0.35)) { dangChay = true }
            withAnimation(.easeOut(duration: tongTg)) { soHienThi = xu }
            DispatchQueue.main.asyncAfter(deadline: .now() + tongTg + 0.6) {
                withAnimation(.easeIn(duration: 0.3)) { dangChay = false }
                batDau = nil
                if let moi = xuCho {
                    xuCho = nil
                    withAnimation(.easeOut(duration: 0.4)) { soHienThi = moi }
                }
            }
        }
    }
}

/// Số Xu đếm chạy (nội suy qua animatableData) — "1.234".
private struct SoXuChay: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View { Text(SoDuCard.so(value.rounded())) }
}

/// Trạng thái trống dùng chung.
struct TKTrong: View {
    let icon: String
    var mau: Color = Theme.textFaint
    let chu: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(mau)
            Text(chu).font(.system(size: 14)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}
