import SwiftUI

/// Bộ khung giao diện chung cho tab Tài khoản và mọi màn mở từ đó (09/11/2026, chủ quán: "style lại toàn bộ tab tài
/// khoản và các màn mở từ đó để đồng bộ"). Cùng ngôn ngữ với thẻ hạng/bảng xếp hạng mới: thẻ trắng bo 18 có bóng nhẹ,
/// tiêu đề có ô icon tô màu, dòng điều hướng kiểu Cài đặt. Màu chủ đạo vẫn là Theme.primary (theo hạng/dịp lễ).
enum TK {
    static let bo: CGFloat = 18
    static let khoangCach: CGFloat = 14
}

extension View {
    /// Thẻ trắng bo góc có bóng nhẹ — khối cơ bản của tab Tài khoản.
    func tkThe(dem: CGFloat = 16) -> some View {
        self
            .padding(dem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TK.bo, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
    }

    /// Nền + lề chung cho màn con (ScrollView chứa các thẻ).
    func tkManHinh() -> some View {
        self
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// Ô icon vuông bo góc tô màu nhạt (kiểu Cài đặt iOS).
struct TKIcon: View {
    let ten: String
    var mau: Color = Theme.primary
    var co: CGFloat = 30

    var body: some View {
        Image(systemName: ten)
            .font(.system(size: co * 0.48, weight: .semibold))
            .foregroundColor(mau)
            .frame(width: co, height: co)
            .background(RoundedRectangle(cornerRadius: co * 0.3, style: .continuous).fill(mau.opacity(0.13)))
    }
}

/// Tiêu đề thẻ: ô icon + chữ đậm, bên phải tuỳ chọn (nút +, link…).
struct TKTieuDe<Phai: View>: View {
    let icon: String
    var mau: Color = Theme.primary
    let tieuDe: String
    @ViewBuilder var phai: () -> Phai

    var body: some View {
        HStack(spacing: 10) {
            TKIcon(ten: icon, mau: mau)
            Text(tieuDe).font(.system(size: 16, weight: .bold))
            Spacer(minLength: 8)
            phai()
        }
    }
}

extension TKTieuDe where Phai == EmptyView {
    init(icon: String, mau: Color = Theme.primary, tieuDe: String) {
        self.init(icon: icon, mau: mau, tieuDe: tieuDe) { EmptyView() }
    }
}

/// Một dòng điều hướng: ô icon + tiêu đề (+ phụ) + giá trị bên phải + mũi tên.
struct TKDong: View {
    let icon: String
    var mau: Color = Theme.primary
    let tieuDe: String
    var phu: String? = nil
    var giaTri: String? = nil
    var muiTen = true
    var mauChu: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            TKIcon(ten: icon, mau: mau)
            VStack(alignment: .leading, spacing: 2) {
                Text(tieuDe).font(.system(size: 15, weight: .semibold)).foregroundColor(mauChu)
                if let phu {
                    Text(phu).font(.system(size: 12)).foregroundColor(Theme.textMuted).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let giaTri {
                Text(giaTri).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.textMuted)
            }
            if muiTen {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textFaint)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Đường kẻ giữa các dòng trong thẻ — thụt vào ngang ô icon.
struct TKKe: View {
    var body: some View { Divider().padding(.leading, 42) }
}

/// Ô nhập liệu cùng kiểu: nền xám nhạt bo góc, không viền.
struct TKONhap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.bg))
            .tint(Theme.primary)
    }
}

extension View {
    func tkONhap() -> some View { modifier(TKONhap()) }
}

/// Thanh lọc dạng viên thuốc (thay tab gạch chân) — dùng ở Lịch sử Xu.
struct TKThanhLoc<T: Hashable>: View {
    let cacMuc: [T]
    let nhan: (T) -> String
    @Binding var chon: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(cacMuc, id: \.self) { m in
                Button { withAnimation(.easeInOut(duration: 0.15)) { chon = m } } label: {
                    Text(nhan(m))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(chon == m ? .white : Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(chon == m ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Color.clear)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 6, y: 2))
    }
}

/// Trạng thái trống dùng chung.
struct TKTrong: View {
    let icon: String
    var mau: Color = Theme.textFaint
    let chu: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(mau)
            Text(chu).font(.system(size: 14)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}
