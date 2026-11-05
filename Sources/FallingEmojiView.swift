import SwiftUI

/// Hạt rơi dạng emoji (trái tim Valentine, cánh hoa Tết...) — cùng cơ chế vật lý với SnowfallView
/// (TimelineView(.animation), seed cố định, rẻ) nhưng vẽ Text thay vì hình tròn, dùng cho các dịp lễ
/// khác Giáng sinh (xem SeasonalEvent.particleSymbol). Đặt .allowsHitTesting(false) ở call site.
struct FallingEmojiView: View {
    let symbol: String

    private struct Flake {
        let xRatio: CGFloat
        let size: CGFloat
        let speed: CGFloat
        let phase: CGFloat
        let drift: CGFloat
    }

    private let flakes: [Flake] = (0..<16).map { i in
        var seed = UInt64(i &* 2654435761 &+ 7)
        func rand() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(1 << 31)
        }
        return Flake(xRatio: rand(), size: 14 + rand() * 8, speed: 22 + rand() * 18, phase: rand() * 2000, drift: 10 + rand() * 16)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                let text = Text(symbol)
                for flake in flakes {
                    let travel = (t * flake.speed + flake.phase).truncatingRemainder(dividingBy: size.height + flake.size * 2)
                    let y = travel - flake.size
                    let x = flake.xRatio * size.width + sin(t * 0.8 + flake.phase) * flake.drift
                    var resolved = context.resolve(text.font(.system(size: flake.size)))
                    resolved.shadow = .init(color: .black.opacity(0.15), radius: 1.5)
                    context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
                }
            }
        }
    }
}
