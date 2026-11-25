import Foundation

enum AuthError: LocalizedError, Equatable {
    case emptyUsername
    case invalidPassword
    case invalidCredentials
    case biometricUnavailable
    case biometricNotEnrolled
    case biometricFailed
    case sessionExpired
    case network
    case unknown
    case api(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyUsername: return "Vui lòng nhập email hoặc số điện thoại."
        case .invalidPassword: return "Mật khẩu phải có ít nhất 6 ký tự."
        case .invalidCredentials: return "Tên đăng nhập hoặc mật khẩu không đúng."
        case .biometricUnavailable: return "Thiết bị chưa hỗ trợ hoặc chưa bật sinh trắc học."
        case .biometricNotEnrolled: return "Hãy đăng nhập bằng mật khẩu một lần để bật đăng nhập sinh trắc học."
        case .biometricFailed: return "Xác thực sinh trắc học không thành công."
        case .sessionExpired: return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }
}
