import UIKit

/// Chuẩn bị ảnh trước khi upload: thu nhỏ cạnh dài nhất và nén JPEG.
/// Ảnh chụp từ iPhone thường 3–8 MB; sau bước này còn khoảng 100–300 KB.
enum AvatarImageProcessor {
    static let maxDimension: CGFloat = 1024
    static let compressionQuality: CGFloat = 0.8

    /// Trả về `nil` nếu dữ liệu không phải ảnh hợp lệ.
    static func jpegData(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }

        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        // Vẽ lại cũng chuẩn hoá hướng ảnh (EXIF orientation) để server nhận ảnh không bị xoay.
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}
