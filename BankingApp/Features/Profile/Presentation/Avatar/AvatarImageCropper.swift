import UIKit

enum AvatarImageCropper {
    /// Cạnh tối đa của ảnh đầu ra (khớp `AvatarImageProcessor.maxDimension`).
    static let maxOutputSide: CGFloat = 1024

    /// Cắt `rect` (theo point của ảnh) thành ảnh vuông. Vẽ lại nên hướng ảnh (EXIF) cũng được chuẩn hoá.
    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard rect.width > 0, rect.height > 0 else { return nil }
        let pixelSide = rect.width * image.scale
        let side = min(maxOutputSide, pixelSide.rounded())
        guard side >= 1 else { return nil }
        let factor = side / rect.width

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(
                x: -rect.minX * factor,
                y: -rect.minY * factor,
                width: image.size.width * factor,
                height: image.size.height * factor
            ))
        }
    }
}
