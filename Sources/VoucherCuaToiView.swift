import SwiftUI

/// Tab "Voucher" riêng — TÁCH ra khỏi tab Ưu đãi (2026-09-15, trước đó nằm chung trong 1 ô nhỏ ở
/// UuDaiView) để voucher trang trọng hơn, mỗi voucher là 1 card riêng kiểu "vé" (tham khảo card mã
/// giảm giá Shopee: khối giá trị giảm bên trái + đường đứt nét có khoét tròn ở giữa + thông tin bên
/// phải), thay vì list rời rạc chữ-với-chữ trong 1 card chung.
struct VoucherCuaToiView: View {
    var notificationBell: AnyView

    @State private var vouchers: [VoucherCuaToi] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Voucher", icon: "ticket", centerTitle: true, trailing: notificationBell)

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vouchers.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(vouchers) { v in
                                VoucherTicketCard(voucher: v)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket").font(.system(size: 40)).foregroundColor(Theme.textFaint)
            Text("Bạn chưa có voucher nào").font(.system(size: 14)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        vouchers = await APIClient.shared.getVoucherCuaToi()
        loading = false
    }
}

/// 1 voucher = 1 card kiểu vé xé — khối trái đậm màu hiện số tiền/phần trăm giảm, khoét 2 nửa hình
/// tròn ở đường phân cách (giả lập vé thật) bằng cách vẽ hình tròn màu NỀN TRANG (Theme.bg) rồi để
/// clipShape của card cắt bớt phần thừa ở mép trên/dưới — không cần GeometryReader vì bề rộng khối
/// trái cố định (leftWidth), .frame(maxWidth/maxHeight: .infinity, alignment:) đủ để 2 hình tròn tự
/// dàn đúng theo chiều cao thật của card (bằng khối HStack, không phải ZStack áp đặt).
private struct VoucherTicketCard: View {
    let voucher: VoucherCuaToi
    private let leftWidth: CGFloat = 96
    private let notchSize: CGFloat = 18

    private var daSuDung: Bool { voucher.daSuDung }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                leftBlock
                dashedDivider
                rightBlock
            }
            Circle().fill(Theme.bg).frame(width: notchSize, height: notchSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: leftWidth - notchSize / 2, y: -notchSize / 2)
            Circle().fill(Theme.bg).frame(width: notchSize, height: notchSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: leftWidth - notchSize / 2, y: notchSize / 2)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.divider))
        .opacity(daSuDung ? 0.55 : 1)
    }

    private var leftBlock: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Text(voucher.nhanGiamGia)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let nhanGiamToiDa = voucher.nhanGiamToiDa {
                Text(nhanGiamToiDa)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .frame(width: leftWidth)
        .padding(.vertical, 16)
        .background(daSuDung ? Theme.textFaint : Theme.primary)
    }

    private var dashedDivider: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height))
            }
            .stroke(Theme.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(width: 1)
    }

    private var rightBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(voucher.ten)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if daSuDung {
                    Text("Đã dùng")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textFaint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.divider))
                }
            }
            if let moTa = voucher.moTa, !moTa.isEmpty {
                Text(moTa)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Image(systemName: "tag.fill").font(.system(size: 10)).foregroundColor(Theme.primary)
                Text(voucher.ma)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.primary)
                Spacer()
                if let donToiThieu = voucher.donToiThieu, donToiThieu > 0 {
                    Text("Đơn từ \(formatTien(donToiThieu))")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textFaint)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
    }
}
