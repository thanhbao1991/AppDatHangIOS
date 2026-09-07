import SwiftUI
import UIKit

/// Port 1:1 từ SearchBar.swift/DateNav.swift bên AppQuanLyIOS — thanh tìm kiếm gradient tràn lên
/// status bar, thay cho .searchable() hệ thống ở các tab gốc để khớp phong cách chung toàn app.
enum HeaderBarMetrics {
    static let rowHeight: CGFloat = 38
    static let verticalPadding: CGFloat = 10
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Tìm..."
    /// Nút phụ đặt bên phải cùng, sau ô tìm kiếm (vd nút "Xem giỏ hàng" thu gọn).
    var trailing: AnyView?
    /// Tô nền gradient brandPrimary tràn lên status bar — khớp DaySearchBar(tinted:) bên AppQuanLyIOS.
    var tinted: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            SearchFieldRow(text: $text, placeholder: placeholder)
            if let trailing { trailing }
        }
        .frame(height: HeaderBarMetrics.rowHeight)
        .padding(.horizontal)
        .padding(.vertical, HeaderBarMetrics.verticalPadding)
        .background(
            Group {
                if tinted {
                    LinearGradient(colors: [Theme.primary, Theme.primary.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .top)
                }
            }
        )
    }
}

/// Không có ô tìm kiếm — dùng cho tab gốc không cần lọc (Đơn của tôi/Cài đặt/Thông báo). Ép cùng
/// HeaderBarMetrics.rowHeight với SearchBar để 4 tab gốc không nhảy chiều cao khi chuyển qua lại,
/// khớp cách DayDateBar ép cùng chiều cao DaySearchBar bên AppQuanLyIOS.
struct TitleBar: View {
    let title: String
    var trailing: AnyView?
    var tinted: Bool = true

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(tinted ? .white : .primary)
            Spacer()
            if let trailing { trailing }
        }
        .frame(height: HeaderBarMetrics.rowHeight)
        .padding(.horizontal)
        .padding(.vertical, HeaderBarMetrics.verticalPadding)
        .background(
            Group {
                if tinted {
                    LinearGradient(colors: [Theme.primary, Theme.primary.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .top)
                }
            }
        )
    }
}

struct SearchFieldRow: View {
    @Binding var text: String
    var placeholder: String = "Tìm..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? Theme.primary : Theme.textMuted)
                .font(.system(size: 14))
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isFocused ? Theme.primary : Color(.separator).opacity(0.4), lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
