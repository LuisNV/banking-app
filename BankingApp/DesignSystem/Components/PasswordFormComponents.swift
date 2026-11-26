import SwiftUI

/// Tiêu đề nhóm kiểu iOS phía trên một nhóm ô nhập ("MẬT KHẨU MỚI").
struct FormSectionTitle: View {
    let title: String
    var uppercase = true

    init(_ title: String, uppercase: Bool = true) {
        self.title = title
        self.uppercase = uppercase
    }

    var body: some View {
        Text(uppercase ? title.uppercased() : title)
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.leading, 20)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Dòng lỗi đỏ dưới một ô nhập; `nil` thì không hiện gì.
struct FormErrorText: View {
    let message: String?

    init(_ message: String?) {
        self.message = message
    }

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(AppColor.danger)
                .padding(.horizontal, 2)
        }
    }
}

/// Thanh độ mạnh mật khẩu.
struct PasswordStrengthRow: View {
    let strength: PasswordStrength

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Độ mạnh").foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(title).fontWeight(.semibold).foregroundStyle(color)
            }
            .font(.footnote)
            ProgressView(value: progress)
                .tint(color)
                .animation(.easeOut(duration: 0.2), value: strength)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Độ mạnh mật khẩu: \(title)")
    }

    private var title: String {
        switch strength {
        case .empty: return "—"
        case .weak: return "Yếu"
        case .medium: return "Trung bình"
        case .strong: return "Mạnh"
        }
    }

    private var color: Color {
        switch strength {
        case .empty: return AppColor.textTertiary
        case .weak: return AppColor.danger
        case .medium: return Color(.systemOrange)
        case .strong: return AppColor.success
        }
    }

    private var progress: Double {
        switch strength {
        case .empty: return 0
        case .weak: return 0.25
        case .medium: return 0.6
        case .strong: return 1
        }
    }
}

/// Nút viên thuốc nhỏ kiểu viền mảnh (Gửi lại mã, Mở Mail).
struct PillChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? AppColor.brand : AppColor.textSecondary)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(AppColor.fieldBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(AppColor.fieldBorder, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
            .frame(minHeight: 44)
    }
}
