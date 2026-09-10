import SwiftUI

/// Port từ OrderStatusScreen.tsx — poll 10s khi màn hình đang mở (bản đầu chưa cần SignalR/push).
private let pollInterval: TimeInterval = 10

struct OrderStatusView: View {
    @Binding var path: [DonHangRoute]
    var notificationBell: AnyView

    @State private var orders: [DonHangKhach] = []
    @State private var loading = true
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Đơn hàng", trailing: notificationBell)

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if orders.isEmpty {
                    Text("Chưa có đơn hàng nào.").foregroundColor(Theme.textFaint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                            cardRow(topExtra: index == 0 ? 6 : 0) {
                                Button { path.append(.detail(order)) } label: {
                                    orderCard(order)
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    .cardListBackground()
                    .refreshable { await load(silent: true) }
                }
            }
        }
        .task {
            await load()
            startPolling()
        }
        .onDisappear { pollTask?.cancel() }
    }

    private func orderCard(_ item: DonHangKhach) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.maHoaDon).fontWeight(.bold)
                Spacer()
                Text(item.ngayGio).font(.system(size: 12)).foregroundColor(Theme.textFaint)
            }
            Text(item.tenMonSummary).font(.system(size: 14)).foregroundColor(Theme.textMuted)
            HStack {
                Text(formatTien(item.thanhTien)).font(.system(size: 16, weight: .bold))
                Spacer()
                Text(item.trangThai.nhan)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(item.trangThai.mau)
                    .clipShape(Capsule())
            }
        }
        .cardBoxStyle()
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true }
        let result = await APIClient.shared.getDonCuaToi()
        orders = result
        loading = false
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await load(silent: true)
            }
        }
    }
}
