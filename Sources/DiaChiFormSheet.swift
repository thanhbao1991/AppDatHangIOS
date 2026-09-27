import SwiftUI

/// Sheet "Thêm/Sửa địa chỉ" ở tab Tài khoản (SettingsView) — thay cho `.alert` TextField cũ, vốn
/// không có chỗ hiện gợi ý tên đường (feedback 2026-09-27 kèm ảnh chụp: "chưa có gợi ý tên đường").
/// Chỉ còn phần nhập text + gợi ý (DiaChiSuggestion.swift, dùng chung với CheckoutView) — KHÔNG có
/// bản đồ/geocode/ước tính ship như CheckoutView vì đây chỉ quản lý danh sách địa chỉ đã lưu, chưa
/// gắn với 1 đơn cụ thể nào để tính ship.
struct DiaChiFormSheet: View {
    let isEditing: Bool
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var text: String
    @State private var tenDuongs: [TenDuong] = []
    @FocusState private var focused: Bool

    init(initialText: String, isEditing: Bool, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self._text = State(initialValue: initialText)
        self.isEditing = isEditing
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var suggestions: [String] {
        guard focused else { return [] }
        return DiaChiSuggestion.matches(for: text, in: tenDuongs)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Địa chỉ giao hàng", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .tint(Theme.primary)
                    .focused($focused)

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { ten in
                            Button { text = DiaChiSuggestion.apply(ten, to: text) } label: {
                                Text(ten)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            if ten != suggestions.last { Divider() }
                        }
                    }
                    .background(Theme.primaryTint.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding()
            .task {
                focused = true
                tenDuongs = await APIClient.shared.getTenDuongList()
            }
            .navigationTitle(isEditing ? "Sửa địa chỉ" : "Thêm địa chỉ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let trimmed = text.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                    }
                }
            }
        }
    }
}
