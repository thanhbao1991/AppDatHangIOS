import SwiftUI

/// Cache ảnh đã decode trong RAM, dùng chung toàn app — AsyncImage của hệ thống KHÔNG cache giữa
/// các instance khác nhau (view mới toanh là coi như chưa từng thấy ảnh này, kể cả URLCache có sẵn
/// byte thô thì vẫn phải decode lại), nên ảnh món ở ProductPickerSheet luôn "tải lại" chậm dù vừa
/// hiện y hệt ở hàng danh sách bên MenuView ngay trước đó. NSCache tự giải phóng khi thiếu RAM.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private init() { cache.countLimit = 300 }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func set(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

/// Thay AsyncImage(url:) ở mọi nơi hiển thị ảnh món trong app — hiện ngay lập tức nếu URL đã từng
/// tải (kể cả từ 1 view khác, vd hàng danh sách), chỉ gọi mạng khi thật sự chưa có trong cache.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url), let img = UIImage(data: data) else { return }
        ImageCache.shared.set(img, for: url)
        uiImage = img
    }
}
