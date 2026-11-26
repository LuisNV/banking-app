import SwiftUI

/// Popup báo lỗi / xác nhận theo thiết kế "Báo lỗi": thẻ trắng giữa màn, biểu tượng tròn,
/// tiêu đề, một câu giải thích và nút viên thuốc. Hiện qua `AppPopupCenter`.
struct AppPopup: Identifiable {
    struct Style: Equatable {
        let systemImage: String
        let tint: Color
        let background: Color

        /// Lỗi nghiệp vụ (vd. email đã được dùng).
        static let error = Style(systemImage: "exclamationmark.triangle", tint: Color(hex: 0xD70015), background: Color(hex: 0xD70015).opacity(0.12))
        /// Mất kết nối mạng.
        static let network = Style(systemImage: "wifi.slash", tint: Color(hex: 0xC93400), background: Color(.systemOrange).opacity(0.16))
        /// Hết phiên đăng nhập.
        static let session = Style(systemImage: "lock", tint: AppColor.brandDark, background: AppColor.brand.opacity(0.12))
        /// Hỏi xác nhận một việc không hoàn tác được (vd. đăng xuất).
        static let confirm = Style(systemImage: "rectangle.portrait.and.arrow.right", tint: Color(hex: 0xD70015), background: Color(hex: 0xD70015).opacity(0.12))
        /// Thiếu quyền (camera, thông báo…).
        static func permission(systemImage: String) -> Style {
            Style(systemImage: systemImage, tint: Color(hex: 0xC93400), background: Color(.systemOrange).opacity(0.16))
        }

        /// Đoán kiểu từ câu lỗi: lỗi mạng và hết phiên có biểu tượng riêng.
        static func inferred(from message: String) -> Style {
            let text = message.lowercased()
            if text.contains("kết nối") || text.contains("mạng") { return .network }
            if text.contains("hết hạn") && text.contains("đăng nhập") { return .session }
            return .error
        }
    }

    struct Action {
        let title: String
        var isDestructive = false
        var handler: () -> Void = {}
    }

    let id = UUID()
    var style: Style
    var title: String
    var message: String
    var primary: Action
    var secondary: Action?
}

extension AppPopup {
    /// Popup lỗi: lỗi mạng có "Thử lại" + "Đóng" (nếu truyền `retry`), còn lại một nút "Đã hiểu".
    static func error(title: String, message: String, retry: (() -> Void)? = nil) -> AppPopup {
        let style = Style.inferred(from: message)
        if style == .network, let retry {
            return AppPopup(
                style: style,
                title: "Mất kết nối",
                message: message,
                primary: Action(title: "Thử lại", handler: retry),
                secondary: Action(title: "Đóng")
            )
        }
        return AppPopup(style: style, title: style == .network ? "Mất kết nối" : title, message: message, primary: Action(title: "Đã hiểu"))
    }

    static func sessionExpired(message: String?, onLogin: @escaping () -> Void = {}) -> AppPopup {
        AppPopup(
            style: .session,
            title: "Phiên đăng nhập đã hết hạn",
            message: message ?? "Vì lý do bảo mật, vui lòng đăng nhập lại để tiếp tục học. Tiến độ của bạn vẫn được giữ nguyên.",
            primary: Action(title: "Đăng nhập lại", handler: onLogin)
        )
    }
}

/// Thẻ popup (không gồm lớp nền tối).
struct AppPopupCard: View {
    let popup: AppPopup
    let onAction: (AppPopup.Action) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: popup.style.systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(popup.style.tint)
                .frame(width: 64, height: 64)
                .background(Circle().fill(popup.style.background))
                .accessibilityHidden(true)

            Text(popup.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)

            Text(popup.message)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Button(popup.primary.title) { onAction(popup.primary) }
                    .buttonStyle(PopupPrimaryButtonStyle(isDestructive: popup.primary.isDestructive))
                if let secondary = popup.secondary {
                    Button(secondary.title) { onAction(secondary) }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(secondary.isDestructive ? AppColor.danger : AppColor.brand)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: 360)
        .background(AppColor.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 25, y: 20)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct PopupPrimaryButtonStyle: ButtonStyle {
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isDestructive ? AppColor.danger : AppColor.brand, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Thông báo lỗi nhẹ trượt xuống ở đầu màn, không chặn thao tác, tự ẩn sau vài giây.
struct AppToast: Identifiable {
    let id = UUID()
    var title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    /// Thời gian hiện (giây) trước khi tự ẩn.
    var duration: TimeInterval = 4
}

struct AppToastView: View {
    let toast: AppToast
    let onAction: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF6961))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color(hex: 0xFF453A).opacity(0.2)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                if let message = toast.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle = toast.actionTitle {
                Button(actionTitle, action: onAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .frame(minHeight: 44)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel("Đóng thông báo")
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(Color(hex: 0x1C1C1E), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 15, y: 10)
        .accessibilityElement(children: .contain)
    }
}
