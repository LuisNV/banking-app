import UIKit
import XCTest
@testable import BankingApp

final class AvatarCropGeometryTests: XCTestCase {
    /// Ảnh ngang 400×200 trong khung tròn 100pt.
    private let sut = AvatarCropGeometry(imageSize: CGSize(width: 400, height: 200), cropDiameter: 100)

    func test_zoomOne_coversCircleWithShortSide() {
        XCTAssertEqual(sut.baseScale, 0.5)
        XCTAssertEqual(sut.displayedSize(zoom: 1), CGSize(width: 200, height: 100))
    }

    func test_defaultCrop_isCenteredSquareOfShortSide() {
        XCTAssertEqual(sut.cropRect(zoom: 1, offset: .zero), CGRect(x: 100, y: 0, width: 200, height: 200))
    }

    func test_offset_isClampedSoImageAlwaysCoversCircle() {
        // zoom 1: chỉ kéo ngang được tối đa (200 − 100) / 2 = 50.
        XCTAssertEqual(sut.clampedOffset(CGSize(width: 80, height: 30), zoom: 1), CGSize(width: 50, height: 0))
        XCTAssertEqual(
            sut.cropRect(zoom: 1, offset: CGSize(width: 999, height: 0)),
            CGRect(x: 0, y: 0, width: 200, height: 200),
            "Kéo hết sang phải → khung nằm ở mép trái ảnh"
        )
    }

    func test_zoomIn_shrinksCropRect() {
        let rect = sut.cropRect(zoom: 2, offset: .zero)
        XCTAssertEqual(rect, CGRect(x: 150, y: 50, width: 100, height: 100))
    }

    func test_zoomIsClamped() {
        XCTAssertEqual(sut.clampedZoom(0.3), 1)
        XCTAssertEqual(sut.clampedZoom(20), 5)
    }

    func test_cropper_outputsSquare_cappedAt1024() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let geometry = AvatarCropGeometry(imageSize: big.size, cropDiameter: 300)

        let output = try XCTUnwrap(AvatarImageCropper.crop(big, to: geometry.cropRect(zoom: 1, offset: .zero)))

        XCTAssertEqual(output.size.width, output.size.height)
        XCTAssertLessThanOrEqual(output.size.width * output.scale, 1024)
    }
}
