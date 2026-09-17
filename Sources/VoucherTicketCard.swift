import SwiftUI

/// Card kiểu vé xé dùng chung cho MỌI nơi hiện voucher (tab Voucher + sheet "Chọn voucher" ở
/// Thanh toán) — tách khỏi VoucherCuaToiView (nơi sinh ra thiết kế này đầu tiên) để 2 màn không lệch
/// nhau khi 1 bên sửa quên bên kia. Nhận thẳng giá trị hiển thị thay vì model cụ thể (VoucherCuaToi
/// hay Voucher là 2 struct khác nhau, không có protocol chung).
struct VoucherTicketCard: View {
    let ten: String
    let moTa: String?
    let ma: String
    let nhanGiam: String
    let nhanGiamToiDa: String?
    var donToiThieu: Double? = nil
    /// Card đã dùng/không còn dùng được — làm mờ + đổi khối trái sang xám, kèm nhãn "Đã dùng".
    var daSuDung: Bool = false
    /// Đang được chọn (sheet "Chọn voucher") — dấu tick tròn góc phải.
    var daChon: Bool = false
    /// "Dùng được tối đa 2 lần/tài khoản"/"Đã dùng 1/2 lần" — nil với voucher không cho dùng lại
    /// (mặc định). Xem VoucherCuaToi.nhanSoLan.
    var nhanSoLan: String? = nil
    /// "Từ 23/09" — voucher CHƯA tới ngày, đang cho khách xem trước để biết mà quay lại đúng dịp.
    /// Chưa dùng được (server từ chối áp dụng) nên card làm mờ giống daSuDung, nhưng nhãn khác hẳn:
    /// "Đã dùng" là hết lượt, cái này là chưa tới lượt. Xem VoucherCuaToi.nhanSapDienRa.
    var nhanSapDienRa: String? = nil

    /// Card không bấm/dùng được lúc này — gộp 2 trạng thái để phần hiển thị mờ dùng chung 1 chỗ.
    private var mo: Bool { daSuDung || nhanSapDienRa != nil }

    private let leftWidth: CGFloat = 96
    private let notchSize: CGFloat = 18

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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.divider, lineWidth: 1))
        .opacity(mo ? 0.55 : 1)
    }

    private var leftBlock: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Text(nhanGiam)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let nhanGiamToiDa {
                Text(nhanGiamToiDa)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .frame(width: leftWidth)
        .padding(.vertical, 16)
        .background(mo ? AnyShapeStyle(Theme.textFaint) : AnyShapeStyle(Theme.primaryGradient))
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
                Text(ten)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if daSuDung {
                    Text("Đã dùng")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textFaint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.divider))
                } else if let nhanSapDienRa {
                    Text(nhanSapDienRa)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.primary))
                } else if daChon {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.primary)
                }
            }
            if let moTa, !moTa.isEmpty {
                Text(moTa)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(2)
            }
            if let nhanSoLan {
                Text("🔁 \(nhanSoLan)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.primary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Image(systemName: "tag.fill").font(.system(size: 10)).foregroundColor(Theme.primary)
                Text(ma)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.primary)
                Spacer()
                if let donToiThieu, donToiThieu > 0 {
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
