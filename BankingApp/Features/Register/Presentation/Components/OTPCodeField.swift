import SwiftUI

/// Ô nhập mã 6 số dạng từng ô, chia nhóm 3–3. Bên dưới là một TextField ẩn
/// để dùng bàn phím số và tự điền mã từ Mail/Tin nhắn (`.oneTimeCode`).
struct OTPCodeField: View {
    let code: String
    var length = RegisterUseCase.codeLength
    let onChange: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: Binding(get: { code }, set: onChange))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityLabel("Mã xác minh \(length) chữ số")
                .accessibilityValue(code.isEmpty ? "Trống" : code.map(String.init).joined(separator: " "))

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { index in
                    if index == length / 2 {
                        Capsule()
                            .fill(AppColor.textTertiary)
                            .frame(width: 10, height: 3)
                    }
                    digitBox(at: index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
            .accessibilityHidden(true)
        }
        .onAppear { isFocused = true }
    }

    private func digitBox(at index: Int) -> some View {
        let digits = Array(code)
        let digit = index < digits.count ? String(digits[index]) : ""
        let isActive = isFocused && index == min(digits.count, length - 1) && digits.count < length

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.fieldBackground)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isActive ? AppColor.brand : AppColor.fieldBorder, lineWidth: isActive ? 2 : 1.5)

            if digit.isEmpty && isActive {
                Capsule()
                    .fill(AppColor.brand)
                    .frame(width: 2, height: 24)
            } else {
                Text(digit)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .frame(width: 46, height: 58)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }
}
