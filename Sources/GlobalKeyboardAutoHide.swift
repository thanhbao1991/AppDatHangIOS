import UIKit

/// Tự ẩn bàn phím sau N giây khách ngừng gõ — áp dụng CHO TOÀN APP, không cần gắn .onChange() riêng
/// từng TextField/TextEditor. Lắng nghe thẳng notification UIKit (TextField/TextEditor của SwiftUI
/// vẫn backing bằng UITextField/UITextView) thay vì mỗi màn tự cài đặt lại, để ô nhập liệu mới thêm
/// sau này ở bất kỳ màn nào cũng tự có hành vi này mà không cần nhớ gắn lại.
@MainActor
final class GlobalKeyboardAutoHide {
    static let shared = GlobalKeyboardAutoHide()

    private let idleSeconds: TimeInterval = 7
    private var task: Task<Void, Never>?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        let handler: (Notification) -> Void = { [weak self] _ in self?.scheduleHide() }
        center.addObserver(forName: UITextField.textDidChangeNotification, object: nil, queue: .main, using: handler)
        center.addObserver(forName: UITextView.textDidChangeNotification, object: nil, queue: .main, using: handler)
    }

    private func scheduleHide() {
        task?.cancel()
        let idleSeconds = idleSeconds
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(idleSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
