import SwiftUI

/// Logo giữ chỗ. TODO: thay bằng logo thật trong Assets.
struct BrandLogo: View {
    var size: CGFloat = 64
    var style: Style = .filled

    enum Style { case filled, onBrand }

    var body: some View {
        Image(systemName: "building.columns")
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                style == .filled ? AppColor.brand : Color.white.opacity(0.18),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .shadow(
                color: style == .filled ? AppColor.brand.opacity(0.25) : .clear,
                radius: 12, y: 8
            )
            .accessibilityHidden(true)
    }
}
