import SwiftUI

/// Cache ảnh đã decode trong RAM + trên ĐĨA, dùng chung toàn app — AsyncImage của hệ thống KHÔNG
/// cache giữa các instance khác nhau (view mới toanh là coi như chưa từng thấy ảnh này, kể cả
/// URLCache có sẵn byte thô thì vẫn phải decode lại), nên ảnh món ở ProductPickerSheet luôn "tải lại"
/// chậm dù vừa hiện y hệt ở hàng danh sách bên MenuView ngay trước đó. NSCache tự giải phóng khi
/// thiếu RAM.
///
/// 2026-09-26: thêm lớp cache ĐĨA (trước đó chỉ có RAM) — phản hồi thực tế "cache rồi sao load hình
/// chậm thế": NSCache mất sạch mỗi lần app bị kill (giống hệt vấn đề JSON catalog đã vá ở
/// APIClient.getMenuDiskSnapshot trước đó), nên tắt mở lại app là coi như chưa từng tải ảnh nào,
/// phải tải lại từ mạng cho MỌI ảnh món dù đã xem qua trước đó rồi.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private let diskCacheDir: URL

    private init() {
        cache.countLimit = 300
        diskCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProductImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    /// RAM trước (nhanh nhất), rơi về ĐĨA nếu RAM chưa có (vd sau khi app vừa mở lại) — đọc được từ
    /// đĩa thì nạp luôn vào RAM cho lần gọi tiếp theo trong cùng phiên nhanh hơn nữa.
    func image(for url: URL) -> UIImage? {
        if let mem = cache.object(forKey: url as NSURL) { return mem }
        guard let data = try? Data(contentsOf: diskPath(for: url)), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: url as NSURL)
        return img
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    /// Ghi RAW bytes xuống đĩa — gọi cùng lúc với set() mỗi khi tải ảnh THẬT từ mạng thành công.
    func setDisk(_ data: Data, for url: URL) {
        try? data.write(to: diskPath(for: url), options: .atomic)
    }

    /// Tên file xác định (deterministic) theo URL — KHÔNG dùng String.hashValue (Swift cố tình
    /// random hoá seed mỗi lần chạy process để chống hash-flooding, nên hashValue đổi khác nhau giữa
    /// các lần mở app, làm cache đĩa lúc nào cũng "miss" dù đã lưu từ phiên trước).
    private func diskPath(for url: URL) -> URL {
        let safe = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return diskCacheDir.appendingPathComponent(safe)
    }
}

/// Thay AsyncImage(url:) ở mọi nơi hiển thị ảnh món trong app — hiện ngay lập tức nếu URL đã từng
/// tải (kể cả từ 1 view khác, vd hàng danh sách, hoặc từ phiên mở app trước đó nhờ cache đĩa), chỉ
/// gọi mạng khi thật sự chưa có trong cache.
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
        ImageCache.shared.setDisk(data, for: url)
        uiImage = img
    }
}
