import SwiftUI

/// Sheet đánh giá đơn — mở NGAY từ card trong tab Đơn hàng (OrderStatusView), không bắt khách phải
/// vào Chi tiết đơn hàng mới đánh giá được (feedback 2026-09-28: "ko cần thiết phải vào chi tiết hoá
/// đơn để đánh giá"). OrderDetailView.danhGiaSection vẫn giữ nguyên bản riêng của nó (khác chỗ: hiện
/// luôn trong trang, không phải sheet) — 2 nơi trùng logic gọi API nhưng khác cách trình bày nên
/// không gộp chung component.
struct DanhGiaSheet: View {
    let hoaDonId: String
    var onDone: (Int) -> Void
    var onCancel: () -> Void

    @State private var pickSao = 0
    @State private var nhanXet = ""
    @State private var dangGui = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { n in
                        Button { pickSao = n } label: {
                            Text(n <= pickSao ? "⭐" : "☆")
                                .font(.system(size: 34))
                                .foregroundColor(n <= pickSao ? nil : Theme.textMuted)
                        }
                    }
                }
                .padding(.top, 12)

                TextField("Nhận xét (không bắt buộc)", text: $nhanXet, axis: .vertical)
                    .textFieldStyle(.roundedBorder).tint(Theme.primary)
                    .lineLimit(3...6)

                if let error {
                    Text(error).font(.system(size: 12)).foregroundColor(Theme.danger)
                }

                Button {
                    Task { await gui() }
                } label: {
                    if dangGui { ProgressView().tint(.white) } else { Text("Gửi đánh giá").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.gradientProminent).disabled(pickSao == 0 || dangGui)

                Spacer()
            }
            .padding()
            .navigationTitle("Đánh giá đơn hàng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onCancel) }
            }
        }
        .presentationDetents([.medium])
    }

    private func gui() async {
        guard pickSao > 0 else { return }
        dangGui = true
        defer { dangGui = false }
        let result = await APIClient.shared.danhGiaDon(hoaDonId: hoaDonId, soSao: pickSao, nhanXet: nhanXet.isEmpty ? nil : nhanXet)
        if result.success {
            onDone(pickSao)
        } else {
            error = result.message ?? "Gửi đánh giá thất bại, thử lại."
        }
    }
}
