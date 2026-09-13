import SwiftUI

/// Danh sách thiết bị đăng nhập — tách khỏi TaiKhoanBaoMatView, chỉ hiện khi khách chủ động bấm
/// vào hàng "Thiết bị đăng nhập" thay vì luôn hiện sẵn trong danh sách chính.
struct ThietBiDangNhapView: View {
    @State private var sessions: [PhienDangNhapKhachHang] = []
    @State private var loading = true
    @State private var revokingSession: PhienDangNhapKhachHang?

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sessions, id: \.id) { item in
                    HStack(spacing: 12) {
                        Text(item.nenTang == "Desktop" ? "🖥️" : "📱")
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.thietBi ?? "Thiết bị không rõ").font(.system(size: 15, weight: .bold))
                                if item.laThietBiHienTai {
                                    Text("Thiết bị này").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 7).padding(.vertical, 2).background(Theme.success).clipShape(Capsule())
                                }
                            }
                            Text(item.nenTang ?? "?").font(.system(size: 12, weight: .bold)).foregroundColor(item.laThietBiHienTai ? Theme.success : Theme.primary)
                            Text("Đăng nhập \(formatUtcShort(item.ngayTao)) · Hết hạn \(formatUtcShort(item.hetHan))")
                                .font(.system(size: 11)).foregroundColor(Theme.textFaint)
                        }
                        Spacer()
                        if !item.laThietBiHienTai {
                            Button { revokingSession = item } label: {
                                Text("❌").foregroundColor(Theme.danger)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Thiết bị đăng nhập")
        .navigationBarTitleDisplayMode(.inline)
        .brandNavBar()
        .task { await load() }
        .confirmationDialog(revokingSession?.thietBi ?? "Thiết bị không rõ", isPresented: Binding(get: { revokingSession != nil }, set: { if !$0 { revokingSession = nil } }), titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                if let s = revokingSession { Task { await revoke(s) } }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Đăng xuất thiết bị này?")
        }
    }

    /// Backend trả DateTime "yyyy-MM-ddTHH:mm:ss.fffffff" (Kind=Unspecified nhưng thực chất UTC) —
    /// ép hậu tố "Z" trước khi parse để không bị hiểu nhầm thành giờ máy.
    private func formatUtcShort(_ iso: String) -> String {
        let trimmed = String(iso.prefix(19)) + "Z"
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: trimmed) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "HH:mm dd/MM"
        out.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return out.string(from: date)
    }

    private func load() async {
        sessions = await APIClient.shared.getSessions()
        loading = false
    }

    private func revoke(_ item: PhienDangNhapKhachHang) async {
        let result = await APIClient.shared.revokeSession(item.id)
        if result.success { sessions.removeAll { $0.id == item.id } }
    }
}
