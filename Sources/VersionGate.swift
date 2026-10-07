import SwiftUI
import UIKit

/// Cổng chặn phiên bản tối thiểu: app lúc mở/quay lại từ nền đọc file JSON tĩnh trên server
/// (TraSuaApp.Backend/wwwroot/app-version/dat-hang.json). Bản cài trên máy cũ hơn `toiThieu` thì bị phủ
/// màn "Cập nhật" toàn màn hình, không dùng tiếp được. Muốn ép cập nhật: sửa `toiThieu` trong file đó rồi
/// scp lên VPS (không cần nộp lại app, không cần restart backend).
///
/// Thiết kế FAIL-OPEN: mất mạng, server lỗi, JSON hỏng, version không đọc được → cho dùng bình thường.
/// Chỉ chặn khi server nói rõ "bản này quá cũ". Đừng đổi sang fail-closed: một lần server sập sẽ khoá
/// toàn bộ khách.
struct AppVersionPolicy: Decodable, Equatable {
    let toiThieu: String
    let linkAppStore: String?
    let thongBao: String?
}

enum VersionGate {
    static let policyURL = URL(string: "https://api.denncoffee.com/app-version/dat-hang.json")!
    static let appStoreFallback = "https://apps.apple.com/app/id6818861243"

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    /// "1.0.2" -> [1, 0, 2]. nil nếu không phải dạng số thuần (bản ipa sideload dùng gitSha làm version
    /// nên không bao giờ bị chặn).
    static func parse(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count) else { return nil }
        var result: [Int] = []
        for p in parts {
            guard !p.isEmpty, p.allSatisfy(\.isNumber), let n = Int(p) else { return nil }
            result.append(n)
        }
        return result
    }

    static func isOutdated(current: String, minimum: String) -> Bool {
        guard var c = parse(current), var m = parse(minimum) else { return false }
        let n = max(c.count, m.count)
        c += Array(repeating: 0, count: n - c.count)
        m += Array(repeating: 0, count: n - m.count)
        return c.lexicographicallyPrecedes(m)
    }

    /// nil khi bất kỳ lỗi nào (xem ghi chú fail-open ở trên).
    static func fetchPolicy() async -> AppVersionPolicy? {
        var req = URLRequest(url: policyURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 5
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(AppVersionPolicy.self, from: data)
    }
}

/// Phủ kín màn hình, không có nút đóng.
struct ForceUpdateView: View {
    let policy: AppVersionPolicy

    var body: some View {
        ZStack {
            Theme.primaryGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
                Text("Cần cập nhật ứng dụng")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(policy.thongBao ?? "Đã có phiên bản mới của Đenn Coffee. Vui lòng cập nhật để tiếp tục đặt món.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button {
                    if let url = URL(string: policy.linkAppStore ?? VersionGate.appStoreFallback) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Cập nhật ngay")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(32)
            .frame(maxWidth: 400)
        }
    }
}
