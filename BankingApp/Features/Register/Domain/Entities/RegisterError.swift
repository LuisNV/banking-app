import Foundation

enum RegisterError: LocalizedError, Equatable {
    case invalidInfo
    case weakPassword
    case emailTaken
    case invalidCode
    case codeExpired
    case network
    case api(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidInfo: return "Thông tin đăng ký chưa hợp lệ. Vui lòng kiểm tra lại."
        case .weakPassword: return "Mật khẩu chưa đáp ứng đủ yêu cầu."
        case .emailTaken: return "Email này đã được dùng cho một tài khoản khác."
        case .invalidCode: return "Mã xác minh không đúng. Vui lòng thử lại."
        case .codeExpired: return "Mã xác minh đã hết hạn. Hãy bấm \"Gửi lại mã\"."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }
}
