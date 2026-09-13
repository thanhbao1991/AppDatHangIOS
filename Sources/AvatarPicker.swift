import PhotosUI
import SwiftUI

extension UIImage {
    /// Center-crop về tỉ lệ 3:4 rồi resize đúng 200x267 — copy y hệt UIImage.resizedForMenuUpload()
    /// bên AppQuanLyIOS (ảnh menu món), theo yêu cầu "crop lưu giống kích thước menu cho nhẹ" thay vì
    /// giữ nguyên full-res từ camera/thư viện ảnh.
    func resizedForMenuUpload() -> UIImage {
        let targetSize = CGSize(width: 200, height: 267)
        let targetRatio = targetSize.width / targetSize.height
        let sourceRatio = size.width / size.height

        var drawSize = targetSize
        if sourceRatio > targetRatio {
            drawSize.width = targetSize.height * sourceRatio
        } else {
            drawSize.height = targetSize.width / sourceRatio
        }
        let origin = CGPoint(x: (targetSize.width - drawSize.width) / 2, y: (targetSize.height - drawSize.height) / 2)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in draw(in: CGRect(origin: origin, size: drawSize)) }
    }
}

/// Avatar tròn tappable — bấm mở thư viện ảnh hệ thống (PhotosPicker chuẩn, khác FavoritesImagePicker
/// bên AppQuanLyIOS vì khách không cần album "Yêu thích" riêng như nhân viên chụp món).
struct AvatarPickerView: View {
    let avatarUrl: String?
    let uploading: Bool
    let onPicked: (Data) -> Void

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                if let avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Circle().fill(Theme.primaryTint)
                        }
                    }
                } else {
                    Circle().fill(Theme.primaryTint)
                    Text("👤").font(.system(size: 26))
                }
                if uploading {
                    Circle().fill(Color.black.opacity(0.35))
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.divider, lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                Text("📷")
                    .font(.system(size: 18))
                    .padding(2)
                    .background(Circle().fill(.white))
            }
        }
        .disabled(uploading)
        .onChange(of: pickerItem) { item in
            Task {
                guard let item, let raw = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: raw),
                      let data = image.resizedForMenuUpload().jpegData(compressionQuality: 0.75) else { return }
                pickerItem = nil
                onPicked(data)
            }
        }
    }
}
