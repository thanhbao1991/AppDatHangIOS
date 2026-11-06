import SwiftUI

/// Màn thoáng qua lúc mở app khi đang dịp lễ, kiểu banner flash sale Shopee — tự tắt sau ~1.8s, chạm
/// vào tắt ngay. Nội dung lấy thẳng SeasonalEvent.active/bannerTitle/bannerSubtitle (câu chúc dịp lễ
/// có sẵn), KHÔNG phải banner khuyến mãi tự nhập riêng. Chỉ hiện 1 lần/ngày, xem
/// SeasonalEvent.canHienSplash/danhDauDaHienSplash.
struct SeasonalSplashView: View {
    let theme: SeasonalTheme
    let onDone: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            if let toanMan = UIImage(named: "ManChao-\(theme.maDaiDien)") {
                manChaoAnhRieng(toanMan)
            } else {
                manChaoTuIcon
            }
        }
        .opacity(visible ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
        }
    }

    /// Ảnh màn chào vẽ riêng cho dịp (Assets ManChao-<MA>, dọc 9:16, logo ở 1/3 trên, giữa để trống) — phủ kín màn
    /// hình, chữ đặt vào khoảng trống giữa (~53% chiều cao). Thêm dịp chỉ cần thêm ảnh, không sửa code.
    private func manChaoAnhRieng(_ anh: UIImage) -> some View {
        GeometryReader { geo in
            Image(uiImage: anh).resizable().scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height).clipped()
            chuChuc
                .frame(width: geo.size.width)
                .position(x: geo.size.width / 2, y: geo.size.height * theme.manChaoChuY)
        }
        .ignoresSafeArea()
    }

    private var manChaoTuIcon: some View {
        ZStack {
            // Nền = chính ảnh icon dịp đã làm nhoè (Assets DipLeNen-<MA>) + lớp tối cho chữ trắng — nền luôn cùng tông
            // với ảnh ở giữa (chủ quán 2026-11-07: nền màu dịp tự chọn đặt cạnh ảnh "lạc lỏng"). Thiếu ảnh thì về nền
            // gradient + hoạ tiết như cũ.
            if let nen = UIImage(named: "DipLeNen-\(theme.maDaiDien)") {
                Color.clear
                    .overlay(Image(uiImage: nen).resizable().scaledToFill())
                    .clipped()
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: [theme.primary, theme.primaryDark], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                hoaTiet
            }

            noiDung
        }
    }

    private var chuChuc: some View {
        let toi = theme.manChaoChuToi
        let mau: Color = toi ? theme.primaryDark : .white
        return VStack(spacing: 10) {
            Text(SeasonalEvent.bannerTitle)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(mau)
                .multilineTextAlignment(.center)
            if !SeasonalEvent.bannerSubtitle.isEmpty {
                Text(SeasonalEvent.bannerSubtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(mau.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 36)
        .shadow(color: toi ? .white.opacity(0.5) : .black.opacity(0.4), radius: 8, y: toi ? 0 : 2)
    }

    private var hoaTiet: some View {
            Canvas { context, size in
                var seed: UInt64 = 9_911
                func rand() -> CGFloat {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return CGFloat(seed >> 33) / CGFloat(1 << 31)
                }
                let symbols = theme.patternSymbols
                context.opacity = 0.18
                for _ in 0..<18 {
                    let x = rand() * size.width
                    let y = rand() * size.height
                    let fontSize: CGFloat = 18 + rand() * 20
                    let resolved = context.resolve(Text(symbols.randomElement() ?? "").font(.system(size: fontSize)))
                    context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
                }
            }
            .ignoresSafeArea()
    }

    private var noiDung: some View {
            VStack(spacing: 14) {
                // Ảnh icon dịp (Assets DipLe-<MA>, bản 600px của AppIcon-<MA>) — chủ quán 2026-11-07. Thiếu ảnh
                // (dịp thêm sau) thì về 2 emoji như cũ.
                if let anh = UIImage(named: "DipLe-\(theme.maDaiDien)") {
                    Image(uiImage: anh)
                        .resizable().scaledToFit()
                        .frame(maxWidth: 240)
                        // Bộ dự phòng chủ quán chọn 2026-11-07: icon bo góc trên nền nhoè (dịp có ảnh riêng thì dùng ảnh riêng).
                        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
                        .padding(.bottom, 10)
                } else {
                    HStack(spacing: 12) {
                        Text(theme.leadingEmoji).font(.system(size: 44))
                        Text(theme.trailingEmoji).font(.system(size: 44))
                    }
                }
                Text(SeasonalEvent.bannerTitle)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if !SeasonalEvent.bannerSubtitle.isEmpty {
                    Text(SeasonalEvent.bannerSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 36)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDone() }
    }
}
