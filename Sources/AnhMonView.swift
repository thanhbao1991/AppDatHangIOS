import SwiftUI
import UIKit

/// Ảnh món ở danh sách/thẻ: món có ảnh ly TÁCH NỀN (hinhAnhCat — PNG/WebP trong suốt do backend phục vụ,
/// xem AnhMonCat.cs) thì app TỰ VẼ nền theo màu theme hiện tại (màu hạng, hoặc màu dịp lễ khi đang lễ) rồi
/// đặt ly lên — đổi theme là nền đổi theo, không cần chụp/ghép lại ảnh. Món không có ảnh tách nền thì giữ
/// như cũ: ảnh JPEG (hinhAnh), chưa có hình thì logo (AnhMonPlaceholder).
struct AnhMonView: View {
    let hinhAnh: String?
    let hinhAnhCat: String?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 12

    /// Theme.primary là static computed (không @Published) và các tham số của view này không đổi khi đổi theme
    /// → SwiftUI bỏ qua vẽ lại. Tự nghe .christmasPreviewToggled (bắn khi dịp lễ/theme đổi) rồi đổi tick để vẽ lại ngay.
    @State private var themeTick = 0

    var body: some View {
        let _ = themeTick
        content
            .onReceive(NotificationCenter.default.publisher(for: .christmasPreviewToggled)) { _ in themeTick += 1 }
    }

    @ViewBuilder
    private var content: some View {
        if let cat = hinhAnhCat, let url = URL(string: cat) {
            ZStack {
                nen
                CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fit) } placeholder: { Color.clear }
                    .padding(min(width, height) * 0.06)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else if let hinhAnh, let url = URL(string: hinhAnh) {
            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            AnhMonPlaceholder(width: width, height: height, cornerRadius: cornerRadius)
        }
    }

    /// Radial: tâm sáng (màu theme pha trắng) → mép đậm (primaryDark) — cùng kiểu nền teal "E" đã duyệt
    /// cho ảnh JPEG. Màu đọc NGAY trong body (không giấu trong closure của GeometryReader — closure không
    /// bắt biến nào bị SwiftUI coi là "không đổi" nên bỏ qua vẽ lại khi theme đổi).
    private var nen: some View {
        RadialGradient(colors: [Theme.primary.pha(trang: 0.38), Theme.primaryDark],
                       center: .center, startRadius: 0, endRadius: max(width, height) * 0.85)
    }
}

private extension Color {
    /// Pha màu với trắng (0 = giữ nguyên, 1 = trắng).
    func pha(trang t: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r + (1 - r) * t, green: g + (1 - g) * t, blue: b + (1 - b) * t)
    }
}
