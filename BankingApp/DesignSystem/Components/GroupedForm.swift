import SwiftUI

/// Ô biểu tượng màu bo góc, giống app Cài đặt của iOS.
struct IconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Thẻ nhóm nền xám bo góc lớn, chứa các dòng ngăn bởi `GroupedDivider`.
struct GroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.vertical, 4)
            .background(
                AppColor.field,
                in: RoundedRectangle(cornerRadius: AppMetrics.groupedCardRadius, style: .continuous)
            )
    }
}

/// Đường kẻ mảnh giữa các dòng, thụt vào bằng bề rộng icon.
struct GroupedDivider: View {
    var leadingInset: CGFloat = 60

    var body: some View {
        Rectangle()
            .fill(AppColor.separator)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

/// Một dòng nhập liệu trong `GroupedCard`: ô biểu tượng + ô nhập + trạng thái đúng/sai.
struct FormFieldRow: View {
    enum Status: Equatable {
        case none, valid, invalid
    }

    let title: String
    let systemImage: String
    let tint: Color
    @Binding var text: String
    var status: Status = .none
    var isSecure = false
    @Binding var isRevealed: Bool
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    init(
        _ title: String,
        systemImage: String,
        tint: Color,
        text: Binding<String>,
        status: Status = .none,
        isSecure: Bool = false,
        isRevealed: Binding<Bool> = .constant(false),
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .never,
        submitLabel: SubmitLabel = .next,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self._text = text
        self.status = status
        self.isSecure = isSecure
        self._isRevealed = isRevealed
        self.textContentType = textContentType
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: systemImage, color: tint)

            Group {
                if isSecure && !isRevealed {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .font(.body)
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)

            statusIcon

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 17))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRevealed ? "Ẩn mật khẩu" : "Hiện mật khẩu")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, isSecure ? 4 : 16)
        .frame(minHeight: 52)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .none:
            EmptyView()
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColor.success)
                .accessibilityLabel("Hợp lệ")
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColor.danger)
                .accessibilityLabel("Chưa hợp lệ")
        }
    }
}
