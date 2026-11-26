import SwiftUI

enum AppColor {
    static let brand = Color(hex: 0x0A5BD3)
    static let brandTint = brand.opacity(0.1)
    /// Chữ màu thương hiệu trên nền trắng/nhạt (nút trên thẻ màu brand).
    static let brandDark = Color(hex: 0x08479F)

    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let field = Color(.secondarySystemBackground)
    static let separator = Color(.separator)

    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    /// Viền ô nhập (kiểu viền mảnh): xám nhạt ở chế độ sáng, trắng mờ ở chế độ tối.
    static let fieldBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.18)
            : UIColor(red: 0xD5 / 255, green: 0xDA / 255, blue: 0xE3 / 255, alpha: 1)
    })
    /// Nền ô nhập: trắng (sáng) / nền hệ thống (tối).
    static let fieldBackground = Color(.systemBackground)
    /// Quầng sáng quanh ô đang nhập.
    static let focusRing = brand.opacity(0.15)
    static let fieldLabel = Color(.label).opacity(0.78)

    static let success = Color(.systemGreen)
    static let danger = Color(.systemRed)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
