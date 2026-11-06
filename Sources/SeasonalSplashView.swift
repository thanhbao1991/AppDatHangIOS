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
            LinearGradient(colors: [theme.primary, theme.primaryDark], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
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

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Text(theme.leadingEmoji).font(.system(size: 44))
                    Text(theme.trailingEmoji).font(.system(size: 44))
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
        }
        .opacity(visible ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDone() }
    }
}
