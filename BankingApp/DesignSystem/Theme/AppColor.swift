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
