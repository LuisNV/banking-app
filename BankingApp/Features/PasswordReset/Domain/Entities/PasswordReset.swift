import Foundation

/// Phiên đặt lại mật khẩu (bước 1 và gửi lại mã trả về).
struct PasswordResetRequest: Equatable {
    let id: String
    /// "EMAIL" hoặc "PHONE".
    let identifierType: String?
    /// Email nhận mã, đã che bớt (vd. "th••••@example.com").
    let destination: String?
    let otpExpiresAt: Date?
    let resendAvailableAt: Date?
    let remainingAttempts: Int?
    /// Cả phiên hết hạn (15 phút).
    let expiresAt: Date?
}

/// Xác minh mã thành công: token ngắn hạn (10 phút) để đặt mật khẩu mới.
struct PasswordResetVerification: Equatable {
    let token: String
    let tokenExpiresAt: Date?
    let email: String?
}

struct PasswordResetResult: Equatable {
    let revokedSessionCount: Int
    let notifiedEmail: String?
    let biometricDisabled: Bool
}

enum PasswordResetField: Hashable {
    case new, confirm
}

enum PasswordResetValidator {
    static let maxBytes = 72

    /// Email hợp lệ, hoặc số điện thoại 10 số bắt đầu bằng 0 (đã chuẩn hoá).
    static func isValidIdentifier(_ raw: String) -> Bool {
        let value = LoginUseCase.normalizedIdentifier(raw)
        if value.contains("@") { return RegistrationValidator.isValidEmail(value) }
        return RegistrationValidator.isValidPhone(value) && value.allSatisfy(\.isNumber)
    }

    static func errors(new: String, confirm: String) -> [PasswordResetField: String] {
        var errors: [PasswordResetField: String] = [:]
        if new.isEmpty {
            errors[.new] = "Vui lòng nhập mật khẩu mới."
        } else if new.utf8.count > maxBytes {
            errors[.new] = "Mật khẩu quá dài (tối đa \(maxBytes) byte)."
        } else if !PasswordEvaluation.evaluate(new).meetsRequirements {
            errors[.new] = "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và ít nhất 1 chữ số."
        }
        if confirm.isEmpty {
            errors[.confirm] = "Vui lòng nhập lại mật khẩu mới."
        } else if confirm != new {
            errors[.confirm] = "Mật khẩu nhập lại không khớp."
        }
        return errors
    }
}

/// Lỗi của luồng quên mật khẩu (mã theo backend). App ưu tiên hiện đúng `message` của server.
enum PasswordResetError: LocalizedError, Equatable {
    case invalidPassword([PasswordResetField: String])
    /// 1025 IDENTIFIER_INVALID (hoặc app kiểm tra trước).
    case invalidIdentifier(message: String?)
    /// 1014 ở bước 1: quá 5 lần/giờ cho mỗi email/SĐT hoặc 20 lần/giờ mỗi IP.
    case tooManyRequests(message: String?)
    /// 1014 lúc gửi lại: đã gửi 5 mã trong phiên → làm lại từ đầu.
    case sendLimitReached
    /// 1013 ("Vui lòng chờ N giây").
    case resendTooSoon(message: String?)
    /// 409 lúc gửi lại: mã đã xác minh rồi.
    case alreadyVerified
    /// 1010 ("Bạn còn N lần thử"). Email/SĐT chưa đăng ký cũng luôn nhận lỗi này.
    case invalidCode(message: String?)
    /// 1011
    case codeExpired(message: String?)
    /// 1012
    case tooManyAttempts(message: String?)
    /// 1008
    case passwordMismatch(message: String?)
    /// 1009
    case weakPassword(message: String?)
    /// 1017
    case sameAsCurrent(message: String?)
    /// 1021 PASSWORD_RESET_NOT_FOUND
    case notFound(message: String?)
    /// 1022 PASSWORD_RESET_EXPIRED
    case expired(message: String?)
    /// 1023 PASSWORD_RESET_NOT_VERIFIED
    case notVerified
    /// 1024 PASSWORD_RESET_TOKEN_INVALID
    case tokenInvalid
    case network
    case api(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidPassword: return "Vui lòng kiểm tra lại mật khẩu."
        case .invalidIdentifier(let message):
            return message.nonEmpty ?? "Vui lòng nhập email hoặc số điện thoại 10 số bắt đầu bằng 0."
        case .tooManyRequests(let message):
            return message.nonEmpty ?? "Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau 1 giờ."
        case .sendLimitReached: return "Đã gửi mã quá nhiều lần. Vui lòng làm lại từ đầu để nhận mã mới."
        case .resendTooSoon(let message): return message.nonEmpty ?? "Vui lòng chờ một chút rồi gửi lại mã."
        case .alreadyVerified: return "Mã đã được xác minh. Hãy đặt mật khẩu mới."
        case .invalidCode(let message): return message.nonEmpty ?? "Mã xác thực không đúng."
        case .codeExpired(let message): return message.nonEmpty ?? "Mã xác thực đã hết hạn, vui lòng gửi lại mã."
        case .tooManyAttempts(let message):
            return message.nonEmpty ?? "Nhập sai quá nhiều lần, vui lòng gửi lại mã mới."
        case .passwordMismatch(let message): return message.nonEmpty ?? "Mật khẩu nhập lại không khớp."
        case .weakPassword(let message):
            return message.nonEmpty ?? "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và ít nhất 1 chữ số."
        case .sameAsCurrent(let message): return message.nonEmpty ?? "Mật khẩu mới phải khác mật khẩu hiện tại."
        case .notFound(let message), .expired(let message):
            return message.nonEmpty ?? "Phiên đặt lại mật khẩu đã hết hạn. Vui lòng làm lại từ đầu."
        case .notVerified: return "Vui lòng nhập mã xác minh trước."
        case .tokenInvalid: return "Phiên xác minh không còn hợp lệ. Vui lòng nhập lại mã."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Không thể đặt lại mật khẩu. Vui lòng thử lại."
        }
    }

    /// Phiên không dùng được nữa → quay về bước 1.
    var requiresRestart: Bool {
        switch self {
        case .notFound, .expired, .sendLimitReached: return true
        default: return false
        }
    }

    /// Mã không còn dùng được → cần "Gửi lại mã".
    var needsNewCode: Bool {
        switch self {
        case .codeExpired, .tooManyAttempts: return true
        default: return false
        }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
