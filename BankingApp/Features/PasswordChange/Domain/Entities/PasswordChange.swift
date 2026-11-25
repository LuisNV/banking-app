import Foundation

/// Yêu cầu đổi mật khẩu đang chờ xác minh (bước 1 trả về).
struct PasswordChangeRequest: Equatable {
    let id: String
    /// Email nhận mã.
    let email: String?
    let logoutOtherDevices: Bool
    /// Mã OTP hết hạn (10 phút).
    let otpExpiresAt: Date?
    /// Lúc được bấm "Gửi lại mã" (cách nhau 45 giây).
    let resendAvailableAt: Date?
    let remainingAttempts: Int?
    /// Cả yêu cầu hết hạn (15 phút).
    let expiresAt: Date?
}

/// Kết quả bước 2.
struct PasswordChangeResult: Equatable {
    let loggedOutOtherDevices: Bool
    /// Số phiên trên thiết bị khác đã bị đăng xuất.
    let revokedSessionCount: Int
}

enum PasswordChangeField: Hashable {
    case current, new, confirm
}

/// Kiểm tra phía app giống `PasswordPolicy` của server, để báo lỗi ngay trên form.
enum PasswordChangeValidator {
    /// BCrypt chỉ dùng 72 byte đầu nên server giới hạn độ dài theo byte UTF-8.
    static let maxBytes = 72

    static func errors(current: String, new: String, confirm: String) -> [PasswordChangeField: String] {
        var errors: [PasswordChangeField: String] = [:]
        if current.isEmpty {
            errors[.current] = "Vui lòng nhập mật khẩu hiện tại."
        }
        if new.isEmpty {
            errors[.new] = "Vui lòng nhập mật khẩu mới."
        } else if new.utf8.count > maxBytes {
            errors[.new] = "Mật khẩu quá dài (tối đa \(maxBytes) byte, khoảng \(maxBytes) ký tự không dấu)."
        } else if !PasswordEvaluation.evaluate(new).meetsRequirements {
            errors[.new] = "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số."
        } else if !current.isEmpty, new == current {
            errors[.new] = "Mật khẩu mới phải khác mật khẩu hiện tại."
        }
        if confirm.isEmpty {
            errors[.confirm] = "Vui lòng nhập lại mật khẩu mới."
        } else if confirm != new {
            errors[.confirm] = "Mật khẩu nhập lại chưa khớp."
        }
        return errors
    }
}

/// Lỗi của luồng đổi mật khẩu (mã theo `ErrorCode.java`). Server trả kèm `message`;
/// app ưu tiên hiện đúng câu đó, trừ 1014 lúc gửi lại mã (câu mặc định của server viết cho luồng đăng ký).
enum PasswordChangeError: LocalizedError, Equatable {
    case invalid([PasswordChangeField: String])
    /// 1002 CURRENT_PASSWORD_INCORRECT ("… Bạn còn N lần thử").
    case wrongCurrentPassword(message: String?)
    /// 1018 PASSWORD_CHECK_LOCKED: sai 5 lần trong 15 phút ("… thử lại sau X phút").
    case locked(message: String?)
    /// 1008 PASSWORD_CONFIRMATION_MISMATCH
    case passwordMismatch(message: String?)
    /// 1009 PASSWORD_TOO_WEAK
    case weakPassword(message: String?)
    /// 1017 PASSWORD_SAME_AS_CURRENT
    case sameAsCurrent(message: String?)
    /// 1016 SESSION_UNKNOWN: không xác định được thiết bị hiện tại, cần đăng nhập lại.
    case sessionUnknown(message: String?)
    /// 1014 ở bước 1: quá 5 yêu cầu mỗi giờ.
    case tooManyRequests(message: String?)
    /// 1010 OTP_INVALID ("… Bạn còn N lần thử").
    case invalidCode(message: String?)
    /// 1011 OTP_EXPIRED
    case codeExpired(message: String?)
    /// 1012 OTP_TOO_MANY_ATTEMPTS
    case tooManyAttempts(message: String?)
    /// 1013 OTP_RESEND_TOO_SOON ("Vui lòng chờ N giây …").
    case resendTooSoon(message: String?)
    /// 1014 lúc gửi lại mã: hết lượt gửi của yêu cầu này.
    case sendLimitReached
    /// 1019 PASSWORD_CHANGE_NOT_FOUND
    case requestNotFound(message: String?)
    /// 1020 PASSWORD_CHANGE_EXPIRED: hết 15 phút, bị huỷ, hoặc mật khẩu đã bị đổi cách khác.
    case requestExpired(message: String?)
    case emailDeliveryFailed
    case sessionExpired
    case network
    case api(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalid: return "Vui lòng kiểm tra lại thông tin."
        case .wrongCurrentPassword(let message): return message.nonEmpty ?? "Mật khẩu hiện tại không đúng."
        case .locked(let message):
            return message.nonEmpty ?? "Bạn đã nhập sai mật khẩu quá nhiều lần. Vui lòng thử lại sau 15 phút."
        case .passwordMismatch(let message): return message.nonEmpty ?? "Mật khẩu nhập lại không khớp."
        case .weakPassword(let message):
            return message.nonEmpty ?? "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và ít nhất 1 chữ số."
        case .sameAsCurrent(let message): return message.nonEmpty ?? "Mật khẩu mới phải khác mật khẩu hiện tại."
        case .sessionUnknown(let message):
            return message.nonEmpty ?? "Không xác định được thiết bị hiện tại, vui lòng đăng nhập lại."
        case .tooManyRequests(let message):
            return message.nonEmpty ?? "Bạn đã yêu cầu đổi mật khẩu quá nhiều lần, vui lòng thử lại sau 1 giờ."
        case .invalidCode(let message): return message.nonEmpty ?? "Mã xác thực không đúng."
        case .codeExpired(let message): return message.nonEmpty ?? "Mã xác thực đã hết hạn, vui lòng gửi lại mã."
        case .tooManyAttempts(let message):
            return message.nonEmpty ?? "Nhập sai quá nhiều lần, vui lòng gửi lại mã mới."
        case .resendTooSoon(let message): return message.nonEmpty ?? "Vui lòng chờ một chút rồi gửi lại mã."
        case .sendLimitReached: return "Đã gửi mã quá nhiều lần. Vui lòng đổi mật khẩu lại từ đầu để nhận mã mới."
        case .requestNotFound(let message):
            return message.nonEmpty ?? "Không tìm thấy yêu cầu đổi mật khẩu. Vui lòng thực hiện lại."
        case .requestExpired(let message):
            return message.nonEmpty ?? "Yêu cầu đổi mật khẩu đã hết hạn, vui lòng thực hiện lại."
        case .emailDeliveryFailed: return "Không gửi được email xác minh. Vui lòng thử lại."
        case .sessionExpired: return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Không thể đổi mật khẩu. Vui lòng thử lại."
        }
    }

    /// Yêu cầu không dùng được nữa → quay lại bước 1.
    var requiresRestart: Bool {
        switch self {
        case .requestExpired, .requestNotFound, .sendLimitReached: return true
        default: return false
        }
    }

    /// Số phút bị khoá đọc từ câu của server ("… thử lại sau 15 phút").
    var lockMinutes: Int? {
        guard case .locked(let message?) = self,
              let range = message.range(of: #"\d+(?=\s*phút)"#, options: .regularExpression)
        else { return nil }
        return Int(message[range])
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
