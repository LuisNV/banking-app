import SwiftUI

/// Nút chính: nền màu thương hiệu, chữ trắng.
/// `isPill = true`: dạng viên thuốc cao 54pt (kiểu iOS 26), dùng ở luồng đăng ký.
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    var isPill = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView().tint(.white)
            }
            configuration.label
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: isPill ? AppMetrics.pillButtonHeight : AppMetrics.buttonHeight)
        .background(
            AppColor.brand.opacity(isEnabled ? 1 : 0.4),
            in: isPill
                ? AnyShape(Capsule())
                : AnyShape(RoundedRectangle(cornerRadius: AppMetrics.buttonRadius, style: .continuous))
        )
        .opacity(configuration.isPressed ? 0.85 : 1)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Nút phụ: nền nhạt cùng tông thương hiệu.
struct TintedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.brand)
            .frame(maxWidth: .infinity)
            .frame(height: AppMetrics.buttonHeight)
            .background(
                AppColor.brandTint,
                in: RoundedRectangle(cornerRadius: AppMetrics.buttonRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Nút tròn icon (nút menu, đóng...). Mặc định kiểu viền mảnh nền trắng;
/// truyền `background` để dùng nền đặc.
struct CircleIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var foreground: Color = AppColor.textPrimary
    var background: Color? = nil
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background ?? AppColor.fieldBackground, in: Circle())
                .overlay {
                    if background == nil {
                        Circle().strokeBorder(AppColor.fieldBorder, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
