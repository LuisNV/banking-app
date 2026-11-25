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

/// Lỗi của luồng đổi mật khẩu. Server trả kèm `message`; app ưu tiên hiện đúng câu đó.
enum PasswordChangeError: LocalizedError, Equatable {
    case invalid([PasswordChangeField: String])
    /// Sai mật khẩu hiện tại ("… Bạn còn N lần thử").
    case wrongCurrentPassword(message: String?)
    /// Sai 5 lần trong 15 phút → khoá 15 phút ("… thử lại sau N phút").
    case locked(message: String?)
    case passwordMismatch
    case weakPassword(message: String?)
    case sameAsCurrent
    /// Chọn đăng xuất thiết bị khác nhưng phiên hiện tại không xác định (`SESSION_UNKNOWN`).
    case sessionUnknown
    /// Quá 5 yêu cầu mỗi giờ.
    case tooManyRequests(message: String?)
    case invalidCode(message: String?)
    case codeExpired
    /// Sai mã 5 lần.
    case tooManyAttempts
    case resendTooSoon(message: String?)
    case sendLimitReached
    /// Yêu cầu hết hạn (15 phút), bị huỷ, hoặc mật khẩu đã bị đổi cách khác (`PASSWORD_CHANGE_EXPIRED`).
    case requestExpired
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
        case .passwordMismatch: return "Mật khẩu nhập lại chưa khớp."
        case .weakPassword(let message):
            return message.nonEmpty ?? "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số."
        case .sameAsCurrent: return "Mật khẩu mới phải khác mật khẩu hiện tại."
        case .sessionUnknown:
            return "Không xác định được phiên đăng nhập trên máy này. Hãy tắt \"Đăng xuất khỏi thiết bị khác\" hoặc đăng nhập lại."
        case .tooManyRequests(let message):
            return message.nonEmpty ?? "Bạn đã yêu cầu đổi mật khẩu quá nhiều lần. Vui lòng thử lại sau."
        case .invalidCode(let message): return message.nonEmpty ?? "Mã xác minh không đúng."
        case .codeExpired: return "Mã xác minh đã hết hạn. Hãy bấm \"Gửi lại mã\"."
        case .tooManyAttempts: return "Bạn đã nhập sai mã quá 5 lần. Hãy bấm \"Gửi lại mã\" để nhận mã mới."
        case .resendTooSoon(let message): return message.nonEmpty ?? "Vui lòng chờ một chút rồi gửi lại mã."
        case .sendLimitReached: return "Bạn đã gửi lại mã quá nhiều lần. Vui lòng đổi mật khẩu lại từ đầu."
        case .requestExpired: return "Yêu cầu đổi mật khẩu đã hết hạn hoặc không còn hiệu lực. Vui lòng thực hiện lại."
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
        case .requestExpired, .sendLimitReached: return true
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
