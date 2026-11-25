import CoreGraphics

/// Tính toán cho màn cắt ảnh đại diện. Thuần logic (không phụ thuộc UI) nên dễ test.
///
/// Ảnh được đặt giữa khung tròn đường kính `cropDiameter` (point), phóng to tối thiểu vừa đủ
/// để phủ kín khung (`zoom = 1`). Người dùng phóng to thêm tối đa `maxZoom` và kéo ảnh,
/// nhưng ảnh luôn phải phủ kín khung (không lộ nền trống).
struct AvatarCropGeometry: Equatable {
    /// Kích thước ảnh (point, đã tính hướng xoay của ảnh).
    let imageSize: CGSize
    let cropDiameter: CGFloat
    var maxZoom: CGFloat = 5

    /// Tỉ lệ point màn hình trên 1 point ảnh khi `zoom = 1` (ảnh vừa phủ kín khung).
    var baseScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return max(cropDiameter / imageSize.width, cropDiameter / imageSize.height)
    }

    func clampedZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, 1), maxZoom)
    }

    /// Kích thước ảnh hiển thị trên màn hình ở mức `zoom`.
    func displayedSize(zoom: CGFloat) -> CGSize {
        let scale = baseScale * clampedZoom(zoom)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    /// Giới hạn độ dịch (tâm ảnh so với tâm khung) để ảnh luôn phủ kín khung.
    func clampedOffset(_ offset: CGSize, zoom: CGFloat) -> CGSize {
        let size = displayedSize(zoom: zoom)
        let maxX = max(0, (size.width - cropDiameter) / 2)
        let maxY = max(0, (size.height - cropDiameter) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    /// Vùng ảnh (theo point của ảnh) nằm trong khung tròn.
    func cropRect(zoom: CGFloat, offset: CGSize) -> CGRect {
        let zoom = clampedZoom(zoom)
        let offset = clampedOffset(offset, zoom: zoom)
        let scale = baseScale * zoom
        let side = cropDiameter / scale
        // Tâm khung nằm ở (tâm ảnh − offset) trên màn hình.
        let centerX = imageSize.width / 2 - offset.width / scale
        let centerY = imageSize.height / 2 - offset.height / scale
        return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)
    }
}
