import Alamofire
import Foundation

/// `{API_BASE_URL}/v1/auth/password-changes`. Cần access token (`requiresAuth` mặc định):
/// gặp 401 thì `AuthInterceptor` tự refresh rồi gửi lại, yêu cầu đổi mật khẩu vẫn còn hiệu lực.
enum PasswordChangeEndpoint: Endpoint {
    case start(PasswordChangeStartRequestDTO)
    case resendOTP(requestId: String)
    case verify(requestId: String, PasswordChangeVerifyRequestDTO)

    private static let base = "v1/auth/password-changes"

    var path: String {
        switch self {
        case .start: return Self.base
        case .resendOTP(let id): return "\(Self.base)/\(id)/otp/resend"
        case .verify(let id, _): return "\(Self.base)/\(id)/verify"
        }
    }

    var method: HTTPMethod { .post }

    var body: (any Encodable)? {
        switch self {
        case .start(let dto): return dto
        case .verify(_, let dto): return dto
        case .resendOTP: return nil
        }
    }

    /// Bước 1 và gửi lại mã chờ server gửi email.
    var timeout: TimeInterval? {
        switch self {
        case .start, .resendOTP: return 60
        case .verify: return nil
        }
    }
}
