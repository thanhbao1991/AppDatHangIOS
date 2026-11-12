import SwiftUI

/// Màn chúc mừng sinh nhật (2026-11-11): từ ĐÚNG ngày sinh nhật tới hết tháng sinh nhật, nếu khách có voucher quà sinh
/// nhật dùng được (đủ điều kiện + chưa dùng — server chỉ trả voucher đó khi đủ, xem VoucherCuaToi.laSinhNhat) thì hiện
/// 1 màn/năm lúc mở app. Xem rồi ghi nhớ trên máy theo năm, RIÊNG từng tài khoản (12/11: 2 người dùng chung máy thì
/// người sau vẫn thấy màn của mình).
enum ChucMungSinhNhat {
    private static var khoaNam: String { "chucMungSinhNhat.namDaXem_\(Prefs.khachHangId ?? "anon")" }

    /// Voucher cần hiện màn chúc mừng, nil = không hiện.
    static func canHien(ngaySinh: SinhNhatInfo?, vouchers: [VoucherCuaToi], homNay: Date = Date()) -> VoucherCuaToi? {
        guard let ns = ngaySinh?.ngaySinh, ngaySinh?.dangTrongThangSinhNhat == true,
              let ngayTrongThang = Int(ns.prefix(10).split(separator: "-").last ?? "") else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        let c = cal.dateComponents([.year, .day], from: homNay)
        guard let nam = c.year, let ngay = c.day, ngay >= ngayTrongThang else { return nil }
        if UserDefaults.standard.integer(forKey: khoaNam) == nam { return nil }
        return vouchers.first { $0.laSinhNhat == true && !$0.daSuDung && !$0.chuaBatDau }
    }

    static func danhDauDaXem(homNay: Date = Date()) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        UserDefaults.standard.set(cal.component(.year, from: homNay), forKey: khoaNam)
    }

    /// Kiểm tra qua API (đã đăng nhập). Lỗi mạng → nil, lần mở sau thử lại.
    static func kiemTra() async -> VoucherCuaToi? {
        async let ns = APIClient.shared.getSinhNhat()
        async let vs = APIClient.shared.getVoucherCuaToi()
        return canHien(ngaySinh: await ns, vouchers: await vs)
    }
}

struct ChucMungSinhNhatView: View {
    let voucher: VoucherCuaToi
    let dong: () -> Void

    @State private var hien = false

    private let hong = Color(red: 0.93, green: 0.25, blue: 0.45)
    private let hongDam = Color(red: 0.70, green: 0.10, blue: 0.32)

    var body: some View {
        ZStack {
            LinearGradient(colors: [hong, hongDam], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            RadialGradient(colors: [.white.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 260)
                .offset(y: -150).ignoresSafeArea()
            PhaoGiayView().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                Text("🎂")
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .scaleEffect(hien ? 1 : 0.2)
                    .rotationEffect(.degrees(hien ? 0 : -30))
                    .animation(.spring(response: 0.6, dampingFraction: 0.55), value: hien)

                Text("CHÚC MỪNG!")
                    .font(.system(size: 15, weight: .heavy)).tracking(3)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 24)
                Text("Sinh nhật vui vẻ")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.top, 6)
                Text("Đenn Coffee có quà nhỏ tặng riêng bạn")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 6)

                // Thẻ voucher
                VStack(spacing: 6) {
                    Text(voucher.nhanGiamGia)
                        .font(.system(size: 44, weight: .heavy)).monospacedDigit()
                        .foregroundColor(.white)
                    if let toiDa = voucher.nhanGiamToiDa {
                        Text(toiDa).font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                    }
                    Text("Voucher Chúc Mừng Sinh Nhật")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .padding(.top, 2)
                }
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 28)
                .padding(.top, 26)
                .opacity(hien ? 1 : 0)
                .offset(y: hien ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: hien)

                Spacer()

                Button(action: dong) {
                    Text("Tuyệt vời")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(hongDam)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .onAppear { hien = true }
    }
}
