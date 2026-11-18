import Foundation

enum PasswordStrength: Equatable {
    case empty, weak, medium, strong
}

/// Đánh giá mật khẩu theo các yêu cầu hiển thị ở bước "Tạo mật khẩu".
struct PasswordEvaluation: Equatable {
    static let minimumLength = 8

    let hasMinimumLength: Bool
    let hasUpperAndLowercase: Bool
    let hasDigit: Bool
    /// Không bắt buộc, chỉ làm mật khẩu mạnh hơn.
    let hasSpecialCharacter: Bool
    let strength: PasswordStrength

    var meetsRequirements: Bool {
        hasMinimumLength && hasUpperAndLowercase && hasDigit
    }

    static func evaluate(_ password: String) -> PasswordEvaluation {
        let hasMinimumLength = password.count >= minimumLength
        let hasUpperAndLowercase = password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase)
        let hasDigit = password.contains(where: \.isNumber)
        let hasSpecial = password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }

        let strength: PasswordStrength
        if password.isEmpty {
            strength = .empty
        } else if !(hasMinimumLength && hasUpperAndLowercase && hasDigit) {
            strength = .weak
        } else if hasSpecial || password.count >= 12 {
            strength = .strong
        } else {
            strength = .medium
        }

        return PasswordEvaluation(
            hasMinimumLength: hasMinimumLength,
            hasUpperAndLowercase: hasUpperAndLowercase,
            hasDigit: hasDigit,
            hasSpecialCharacter: hasSpecial,
            strength: strength
        )
    }
}
