import SwiftUI

/// Ô biểu tượng màu bo góc, giống app Cài đặt của iOS.
struct IconTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Thẻ nhóm viền mảnh nền trắng bo góc lớn, chứa các dòng ngăn bởi `GroupedDivider`.
struct GroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.vertical, 4)
            .outlinedSurface()
    }
}

/// Đường kẻ mảnh giữa các dòng, thụt vào bằng bề rộng icon.
struct GroupedDivider: View {
    var leadingInset: CGFloat = 60

    var body: some View {
        Rectangle()
            .fill(AppColor.rowDivider)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}
