import SwiftUI

/// Hiệu ứng tuyết rơi nhẹ cho dịp Giáng sinh (Theme.isChristmasSeason) — TimelineView(.animation) vẽ
/// lại vị trí bông tuyết theo thời gian trôi (hàm xác định của t, không giữ @State per-frame) nên rẻ,
/// không ảnh hưởng hiệu năng cuộn menu bên dưới. Đặt .allowsHitTesting(false) ở call site để không
/// chặn chạm vào món/nút phía dưới.
struct SnowfallView: View {
    private struct Flake {
        let xRatio: CGFloat
        let size: CGFloat
        let speed: CGFloat
        let phase: CGFloat
        let drift: CGFloat
    }

    /// Seed cố định (không dùng Double.random) để layout tuyết giống nhau mỗi lần mở màn, tránh tuyết
    /// "nhảy" vị trí khi SwiftUI tái tạo view (vd đổi tab rồi quay lại).
    private let flakes: [Flake] = (0..<18).map { i in
        var seed = UInt64(i &* 2654435761 &+ 1)
        func rand() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(1 << 31)
        }
        return Flake(xRatio: rand(), size: 4 + rand() * 5, speed: 26 + rand() * 22, phase: rand() * 2000, drift: 8 + rand() * 14)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                for flake in flakes {
                    let travel = (t * flake.speed + flake.phase).truncatingRemainder(dividingBy: size.height + flake.size * 2)
                    let y = travel - flake.size
                    let x = flake.xRatio * size.width + sin(t * 0.8 + flake.phase) * flake.drift
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: flake.size, height: flake.size)), with: .color(.white.opacity(0.85)))
                }
            }
        }
    }
}
