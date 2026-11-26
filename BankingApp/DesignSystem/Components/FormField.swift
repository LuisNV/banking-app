import SwiftUI

/// Trạng thái hiển thị của một ô nhập.
enum FormFieldStatus: Equatable {
    case none, valid, invalid
}

/// Khung ô nhập kiểu "viền mảnh": nhãn phía trên, hộp nền trắng viền xám mảnh.
/// Đang nhập: viền xanh + quầng sáng; lỗi: viền đỏ. Dùng chung cho ô chữ, chọn ngày, chọn giới tính…
struct FormFieldBox<Content: View>: View {
    let label: String
    var status: FormFieldStatus = .none
    var isFocused = false
    var minHeight: CGFloat = 52
    @ViewBuilder let content: Content

    private var borderColor: Color {
        if status == .invalid { return AppColor.danger }
        return isFocused ? AppColor.brand : AppColor.fieldBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(status == .invalid ? AppColor.danger : AppColor.fieldLabel)
                .accessibilityHidden(true)

            content
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .background(AppColor.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isFocused || status == .invalid ? 2 : 1.5)
                }
                .background {
                    // Quầng sáng chỉ khi đang nhập.
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFocused ? (status == .invalid ? AppColor.danger.opacity(0.12) : AppColor.focusRing) : .clear)
                        .padding(-4)
                }
                .animation(.easeOut(duration: 0.15), value: isFocused)
                .animation(.easeOut(duration: 0.15), value: status)
        }
    }
}

/// Ô nhập chữ kiểu viền mảnh. Hỗ trợ mật khẩu (nút hiện/ẩn), trạng thái đúng/sai và nhiều dòng.
struct FormField: View {
    let title: String
    @Binding var text: String
    var status: FormFieldStatus = .none
    var isSecure = false
    @Binding var isRevealed: Bool
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .next
    var isMultiline = false
    var onSubmit: () -> Void = {}
    /// Ô đang được nhập (bên gọi biết qua `@FocusState`) để vẽ viền xanh.
    var isFocused = false

    init(
        _ title: String,
        text: Binding<String>,
        status: FormFieldStatus = .none,
        isSecure: Bool = false,
        isRevealed: Binding<Bool> = .constant(false),
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .never,
        submitLabel: SubmitLabel = .next,
        isMultiline: Bool = false,
        onSubmit: @escaping () -> Void = {},
        isFocused: Bool = false
    ) {
        self.title = title
        self._text = text
        self.status = status
        self.isSecure = isSecure
        self._isRevealed = isRevealed
        self.textContentType = textContentType
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.submitLabel = submitLabel
        self.isMultiline = isMultiline
        self.onSubmit = onSubmit
        self.isFocused = isFocused
    }

    var body: some View {
        FormFieldBox(label: title, status: status, isFocused: isFocused) {
            HStack(spacing: 8) {
                input
                    .font(.body)
                    .textContentType(textContentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .accessibilityLabel(title)
                    .padding(.vertical, isMultiline ? 14 : 0)

                statusIcon

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 17))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 40, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                }
            }
        }
    }

    @ViewBuilder
    private var input: some View {
        if isSecure && !isRevealed {
            SecureField(title, text: $text, prompt: Text(""))
        } else if isMultiline {
            TextField(title, text: $text, prompt: Text(""), axis: .vertical)
                .lineLimit(1...4)
        } else {
            TextField(title, text: $text, prompt: Text(""))
        }
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
                .padding(.trailing, isSecure ? 0 : 6)
                .accessibilityLabel("Hợp lệ")
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColor.danger)
                .padding(.trailing, isSecure ? 0 : 6)
                .accessibilityLabel("Chưa hợp lệ")
        }
    }
}

/// Xếp các phần tử thành hàng, hết chỗ thì xuống dòng (dùng cho thẻ yêu cầu mật khẩu).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Thẻ yêu cầu mật khẩu: xanh lá khi đạt, viền xám khi chưa.
struct PasswordRequirementChip: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isMet ? AppColor.success : AppColor.textTertiary)
                .contentTransition(.symbolEffect(.replace))
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isMet ? Color(hex: 0x1E7A37) : AppColor.textSecondary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: 30)
        .background {
            Capsule().fill(isMet ? AppColor.success.opacity(0.14) : .clear)
        }
        .overlay {
            Capsule().strokeBorder(isMet ? .clear : AppColor.fieldBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isMet ? "Đạt" : "Chưa đạt")
    }
}

/// Thẻ viền mảnh (không nền xám) cho công tắc, chọn ngày… nằm giữa các ô nhập.
struct OutlinedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(AppColor.fieldBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColor.fieldBorder, lineWidth: 1.5)
            }
    }
}
