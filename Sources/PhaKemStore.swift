import Foundation

/// "Pha kèm" (chủ quán 19/11/2026): món vừa có đơn khác đặt thì trong 3 phút khách đặt thêm đúng món đó được giảm 3K/ly
/// (bất kể size, không giảm topping) — quán pha gộp cùng mẻ. Server quyết định món nào/còn bao lâu
/// (GET /dat-hang/menu/pha-kem, DatHangService.PhaKem bên Backend); app chỉ hiện + báo lại số giảm lúc đặt.
///
/// Bảng tra đọc ĐỒNG BỘ được từ mọi nơi (CartItem.giamPhaKem là computed property của struct) nên giữ dưới khoá;
/// ObservableObject chỉ để báo SwiftUI vẽ lại khi bảng đổi / có món vừa hết giờ.
enum PhaKemBang {
    private static let lock = NSLock()
    private static var bang: [String: (giam: Double, hetLuc: Date)] = [:]

    static func giam(_ sanPhamId: String?, luc: Date = Date()) -> Double {
        guard let sanPhamId else { return 0 }
        lock.lock(); defer { lock.unlock() }
        guard let m = bang[sanPhamId], m.hetLuc > luc else { return 0 }
        return m.giam
    }

    static func hetLuc(_ sanPhamId: String) -> Date? {
        lock.lock(); defer { lock.unlock() }
        return bang[sanPhamId]?.hetLuc
    }

    static func ganMoi(_ moi: [String: (giam: Double, hetLuc: Date)]) {
        lock.lock(); bang = moi; lock.unlock()
    }

    static func dangPha(luc: Date = Date()) -> [(sanPhamId: String, hetLuc: Date)] {
        lock.lock(); defer { lock.unlock() }
        return bang.filter { $0.value.hetLuc > luc }.map { ($0.key, $0.value.hetLuc) }.sorted { $0.hetLuc < $1.hetLuc }
    }
}

@MainActor
final class PhaKemStore: ObservableObject {
    static let shared = PhaKemStore()

    /// Đổi mỗi lần bảng đổi / có món hết giờ — view đọc biến này để SwiftUI biết phải vẽ lại.
    @Published private(set) var phienBan = 0

    private var lanTaiCuoi: Date?
    private var henHetGio: Task<Void, Never>?
    /// Hỏi lại server mỗi 10s khi màn Thực đơn / Giỏ hàng đang mở (không cần realtime: món giữ giá 3 phút).
    private static let chuKy: UInt64 = 10

    /// Gọi trong `.task {}` của màn cần — SwiftUI tự huỷ khi rời màn nên vòng lặp dừng theo.
    func chay() async {
        while !Task.isCancelled {
            await taiLai()
            try? await Task.sleep(nanoseconds: Self.chuKy * 1_000_000_000)
        }
    }

    /// `batBuoc`: bỏ qua chống gọi dồn (vd server vừa báo hết giờ lúc đặt đơn).
    func taiLai(batBuoc: Bool = false) async {
        if !batBuoc, let t = lanTaiCuoi, Date().timeIntervalSince(t) < 8 { return }
        lanTaiCuoi = Date()
        guard let ds = await APIClient.shared.getPhaKem() else { return } // lỗi mạng: giữ bảng cũ, tự hết giờ theo hetLuc
        let bayGio = Date()
        var moi: [String: (giam: Double, hetLuc: Date)] = [:]
        for m in ds where m.conGiay > 0 && m.giamGia > 0 {
            moi[m.sanPhamId] = (m.giamGia, bayGio.addingTimeInterval(TimeInterval(m.conGiay)))
        }
        tuServer = moi
        apDung()
    }

    private var tuServer: [String: (giam: Double, hetLuc: Date)] = [:]

    private func apDung() {
        var bang = tuServer
        #if DEV_LOGIN
        for (id, m) in xemThu where m.hetLuc > Date() { bang[id] = m }
        #endif
        PhaKemBang.ganMoi(bang)
        phienBan += 1
        henLanHetGioKeTiep()
    }

    #if DEV_LOGIN
    /// Bản dev "🧪 Xem thử Sale off": giả vài món đang pha 3 phút, CHỈ trên máy này (server không biết — đặt đơn sẽ bị
    /// báo hết giờ, đúng như khách thật đặt trễ).
    private var xemThu: [String: (giam: Double, hetLuc: Date)] = [:]

    func batXemThu(_ sanPhamIds: [String]) {
        let het = Date().addingTimeInterval(180)
        xemThu = Dictionary(sanPhamIds.map { ($0, (giam: 3000.0, hetLuc: het)) }, uniquingKeysWith: { a, _ in a })
        apDung()
    }
    #endif

    /// Món sớm hết giờ nhất hết thì vẽ lại ngay (giá trong giỏ/menu trở về giá thường đúng lúc).
    private func henLanHetGioKeTiep() {
        henHetGio?.cancel()
        guard let ganNhat = PhaKemBang.dangPha().first?.hetLuc else { return }
        let giay = max(0.2, ganNhat.timeIntervalSinceNow + 0.2)
        henHetGio = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(giay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.phienBan += 1
            self.henLanHetGioKeTiep()
        }
    }

    /// "2:41"
    static func demNguoc(_ hetLuc: Date, luc: Date) -> String {
        let s = max(0, Int(hetLuc.timeIntervalSince(luc).rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Server trả lỗi này khi app báo giảm mà món vừa hết giờ (Messages.DatHang.HetPhaKem).
    static let tienToHetGio = "HET_PHA_KEM:"
}
