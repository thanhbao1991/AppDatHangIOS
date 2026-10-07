import SwiftUI

/// Ảnh thay thế cho món chưa có hình: logo thương hiệu (cùng ảnh icon app) — thay cho ô emoji ly
/// mặc định trước đây (nhìn như thiếu dữ liệu) và cho mọi dòng giữ đúng kích thước, không lệch lề
/// giữa món có ảnh và món chưa có ảnh.
struct AnhMonPlaceholder: View {
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        Image("BrandPlaceholder")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
