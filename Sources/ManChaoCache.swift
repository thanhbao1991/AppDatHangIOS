import UIKit

/// Ảnh màn chào dịp lễ KHÔNG nằm trong file cài (đỡ nặng app) — server phục vụ ở /man-chao-dip-le/<MA>.jpg, app tải
/// ngầm khi dịp vào cửa sổ giao diện (SeasonalEvent.load) rồi lưu vào Caches. Có ảnh thì màn chào dùng ảnh riêng,
/// chưa có/mất mạng thì SeasonalSplashView dùng bộ dự phòng (icon bo góc trên nền nhoè, có sẵn trong app).
/// Đổi ảnh trên server → ?v=<hash> đổi → app tải lại.
enum ManChaoCache {
    private static let goc = URL(string: "https://api.denncoffee.com")!

    private static func thuMuc() -> URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("man-chao", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func file(_ ma: String) -> URL { thuMuc().appendingPathComponent("\(ma).jpg") }
    private static func khoaPhienBan(_ ma: String) -> String { "manChao.v.\(ma)" }

    /// Ảnh đã tải của dịp (nil = chưa có).
    static func anh(ma: String) -> UIImage? {
        UIImage(contentsOfFile: file(ma).path)
    }

    /// `duongDan` = DipLe.anhManChao từ server ("/man-chao-dip-le/NOEL.jpg?v=abc"); nil (xem trước) = đường dẫn mặc định,
    /// luôn tải lại. Lỗi mạng/404 bỏ qua im lặng — màn chào tự về bộ dự phòng.
    static func taiNeuCan(ma: String, duongDan: String?) async {
        let ud = UserDefaults.standard
        let coSan = FileManager.default.fileExists(atPath: file(ma).path)
        let path = duongDan ?? "/man-chao-dip-le/\(ma).jpg"
        let phienBan = URLComponents(string: path)?.queryItems?.first(where: { $0.name == "v" })?.value
        // duongDan nil = xem trước (bản dev): luôn tải lại để thấy ảnh mới nhất trên server, không kẹt ảnh cũ trong máy.
        if coSan, duongDan != nil, ud.string(forKey: khoaPhienBan(ma)) == phienBan { return }
        guard let url = URL(string: path, relativeTo: goc)?.absoluteURL else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              UIImage(data: data) != nil else { return }
        guard (try? data.write(to: file(ma), options: .atomic)) != nil else { return }
        if let phienBan { ud.set(phienBan, forKey: khoaPhienBan(ma)) }
    }
}
