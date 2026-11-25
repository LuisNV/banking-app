import Foundation

/// Lỗi của luồng đăng ký. Mã 1003–1014, 502, 503 theo hợp đồng backend.
enum RegisterError: LocalizedError, Equatable {
    case invalidInfo
    case weakPassword
    /// 1003
    case emailTaken
    /// 1004
    case phoneTaken
    /// 1005: không tìm thấy phiên.
    case sessionNotFound
    /// 1006: phiên quá 60 phút.
    case sessionExpired
    /// 1007: sai bước (vd. hoàn tất khi chưa xác minh).
    case wrongStep
    /// 1008
    case passwordMismatch
    /// 1010: kèm thông báo của server ("Bạn còn N lần thử").
    case invalidCode(message: String?)
    /// 1011
    case codeExpired
    /// 1012: sai quá 5 lần.
    case tooManyAttempts
    /// 1013: chưa đủ 45 giây ("Vui lòng chờ N giây").
    case resendTooSoon(message: String?)
    /// 1014
    case sendLimitReached
    /// 502
    case emailDeliveryFailed
    /// 503
    case emailServiceUnavailable
    case network
    case api(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidInfo: return "Thông tin đăng ký chưa hợp lệ. Vui lòng kiểm tra lại."
        case .weakPassword: return "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và ít nhất 1 chữ số."
        case .emailTaken: return "Email này đã được dùng cho một tài khoản khác."
        case .phoneTaken: return "Số điện thoại này đã được dùng cho một tài khoản khác."
        case .sessionNotFound: return "Không tìm thấy phiên đăng ký. Vui lòng bắt đầu lại."
        case .sessionExpired: return "Phiên đăng ký đã hết hạn (quá 60 phút). Vui lòng bắt đầu lại."
        case .wrongStep: return "Bước đăng ký không hợp lệ. Vui lòng thử lại."
        case .passwordMismatch: return "Mật khẩu nhập lại không khớp."
        case .invalidCode(let message):
            return message.flatMap { $0.isEmpty ? nil : $0 } ?? "Mã xác minh không đúng. Vui lòng thử lại."
        case .codeExpired: return "Mã xác minh đã hết hạn. Hãy bấm \"Gửi lại mã\"."
        case .tooManyAttempts: return "Bạn đã nhập sai quá 5 lần. Hãy bấm \"Gửi lại mã\" để nhận mã mới."
        case .resendTooSoon(let message):
            return message.flatMap { $0.isEmpty ? nil : $0 } ?? "Vui lòng chờ một chút rồi gửi lại mã."
        case .sendLimitReached: return "Bạn đã yêu cầu gửi mã quá nhiều lần. Vui lòng thử lại sau."
        case .emailDeliveryFailed: return "Không gửi được email xác minh. Vui lòng thử lại."
        case .emailServiceUnavailable: return "Hệ thống gửi email đang tạm ngưng. Vui lòng thử lại sau."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }

    /// Phiên không dùng được nữa → phải tạo phiên mới từ bước 1.
    var requiresRestart: Bool {
        self == .sessionNotFound || self == .sessionExpired
    }
}
