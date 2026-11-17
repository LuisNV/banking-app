import SwiftUI

/// Ô nhập liệu nền xám bo góc, có icon bên trái. Hỗ trợ chế độ mật khẩu có nút hiện/ẩn.
struct AppTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var isSecure = false
    @Binding var isRevealed: Bool
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    init(
        _ title: String,
        systemImage: String,
        text: Binding<String>,
        isSecure: Bool = false,
        isRevealed: Binding<Bool> = .constant(false),
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        submitLabel: SubmitLabel = .next,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.title = title
        self.systemImage = systemImage
        self._text = text
        self.isSecure = isSecure
        self._isRevealed = isRevealed
        self.textContentType = textContentType
        self.keyboardType = keyboardType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 22)
                .accessibilityHidden(true)

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
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRevealed ? "Ẩn mật khẩu" : "Hiện mật khẩu")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, isSecure ? 4 : 16)
        .frame(height: AppMetrics.fieldHeight)
        .background(
            AppColor.field,
            in: RoundedRectangle(cornerRadius: AppMetrics.fieldRadius, style: .continuous)
        )
    }
}
