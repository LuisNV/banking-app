import SwiftUI

/// Tiêu đề nhóm kiểu iOS phía trên một `GroupedCard` ("MẬT KHẨU MỚI").
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
                .padding(.horizontal, 20)
                .padding(.top, 2)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

/// Một yêu cầu mật khẩu: dấu ✓ xanh khi đạt, vòng tròn rỗng khi chưa.
struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isMet ? AppColor.success : AppColor.textTertiary)
                .contentTransition(.symbolEffect(.replace))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isMet ? AppColor.textPrimary : AppColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isMet ? "Đạt" : "Chưa đạt")
    }
}

/// Nút viên thuốc nhỏ nền xám (Gửi lại mã, Mở Mail).
struct PillChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? AppColor.brand : AppColor.textSecondary)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(AppColor.field, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
            .frame(minHeight: 44)
    }
}
