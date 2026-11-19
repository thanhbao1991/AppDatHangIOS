import SwiftUI

/// Cache ảnh đã decode trong RAM + trên ĐĨA, dùng chung toàn app — AsyncImage của hệ thống KHÔNG
/// cache giữa các instance khác nhau (view mới toanh là coi như chưa từng thấy ảnh này, kể cả
/// URLCache có sẵn byte thô thì vẫn phải decode lại), nên ảnh món ở ProductPickerSheet luôn "tải lại"
/// chậm dù vừa hiện y hệt ở hàng danh sách bên MenuView ngay trước đó. NSCache tự giải phóng khi
/// thiếu RAM.
///
/// 2026-09-26: thêm lớp cache ĐĨA (trước đó chỉ có RAM) — NSCache mất sạch mỗi lần app bị kill.
///
/// 19/11/2026 (sửa lag cuộn tab Thực đơn): trước đây đọc đĩa + `UIImage(data:)` chạy TRÊN LUỒNG GIAO DIỆN (.task của
/// view là MainActor) và giữ ảnh KÍCH THƯỚC GỐC — UIImage giải nén lười lúc vẽ lần đầu, nên mỗi dòng món mới lộ ra
/// khi cuộn là giải nén cả ảnh to trên main thread → khựng. Giờ đọc đĩa + giải nén + thu nhỏ đúng cỡ hiển thị ở luồng
/// nền (preparingThumbnail), RAM giữ bản đã giải nén sẵn theo từng cỡ.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let diskCacheDir: URL

    private init() {
        cache.countLimit = 400
        diskCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProductImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    /// Khoá RAM theo URL + cỡ pixel (0 = cỡ gốc) — cùng 1 ảnh hiện ở dòng món (nhỏ) và màn chọn món (to) là 2 bản.
    private func khoa(_ url: URL, _ px: Int) -> NSString { "\(url.absoluteString)#\(px)" as NSString }

    /// Chỉ RAM — rẻ, gọi được trên main thread (vd lúc dựng view để khỏi nháy placeholder).
    func memoryImage(for url: URL, px: Int) -> UIImage? { cache.object(forKey: khoa(url, px)) }

    /// RAM → đĩa → mạng. Đọc đĩa / giải nén / thu nhỏ đều ở luồng nền.
    func load(_ url: URL, px: Int) async -> UIImage? {
        if let mem = memoryImage(for: url, px: px) { return mem }
        let path = diskPath(for: url)
        if let img = await Task.detached(priority: .userInitiated, operation: { () -> UIImage? in
            guard let data = try? Data(contentsOf: path) else { return nil }
            return Self.giaiNen(data, px: px)
        }).value {
            cache.setObject(img, forKey: khoa(url, px))
            return img
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let img = Self.giaiNen(data, px: px) else { return nil }
            try? data.write(to: path, options: .atomic)
            return img
        }.value
        if let img { cache.setObject(img, forKey: khoa(url, px)) }
        return img
    }

    /// Giải nén sẵn (không để dành tới lúc vẽ trên main thread); px > 0 thì thu nhỏ để cạnh dài nhất = px.
    private static func giaiNen(_ data: Data, px: Int) -> UIImage? {
        guard let img = UIImage(data: data) else { return nil }
        let w = img.size.width * img.scale, h = img.size.height * img.scale
        if px > 0, max(w, h) > CGFloat(px) {
            let k = CGFloat(px) / max(w, h)
            if let nho = img.preparingThumbnail(of: CGSize(width: (w * k).rounded(), height: (h * k).rounded())) { return nho }
        }
        return img.preparingForDisplay() ?? img
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
/// tải (kể cả từ 1 view khác, hoặc từ phiên mở app trước nhờ cache đĩa), chỉ gọi mạng khi thật sự chưa có.
/// `kichThuoc`: cạnh dài nhất lúc hiển thị (point) — có thì ảnh được thu nhỏ đúng cỡ (nhẹ RAM, vẽ nhanh khi cuộn).
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    var kichThuoc: CGFloat? = nil
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    init(url: URL?, kichThuoc: CGFloat? = nil, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.kichThuoc = kichThuoc
        self.content = content
        self.placeholder = placeholder
        // Đã có trong RAM thì hiện ngay từ lần vẽ đầu — không nháy placeholder khi dòng cuộn ra rồi vào lại.
        if let url { _uiImage = State(initialValue: ImageCache.shared.memoryImage(for: url, px: Self.px(kichThuoc))) }
    }

    private static func px(_ kichThuoc: CGFloat?) -> Int {
        guard let kichThuoc, kichThuoc > 0 else { return 0 }
        return Int((kichThuoc * UIScreen.main.scale).rounded(.up))
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let img = await ImageCache.shared.load(url, px: Self.px(kichThuoc)), img !== uiImage { uiImage = img }
        }
    }
}
