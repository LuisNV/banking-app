import Alamofire
import Foundation

/// `{API_BASE_URL}/v1/auth/password-resets`. Không cần token.
enum PasswordResetEndpoint: Endpoint {
    case start(PasswordResetStartRequestDTO)
    case resendOTP(resetId: String)
    case verify(resetId: String, PasswordResetVerifyRequestDTO)
    case complete(resetId: String, PasswordResetCompleteRequestDTO)

    private static let base = "v1/auth/password-resets"

    var path: String {
        switch self {
        case .start: return Self.base
        case .resendOTP(let id): return "\(Self.base)/\(id)/otp/resend"
        case .verify(let id, _): return "\(Self.base)/\(id)/verify"
        case .complete(let id, _): return "\(Self.base)/\(id)/complete"
        }
    }

    var method: HTTPMethod { .post }

    var body: (any Encodable)? {
        switch self {
        case .start(let dto): return dto
        case .verify(_, let dto): return dto
        case .complete(_, let dto): return dto
        case .resendOTP: return nil
        }
    }

    var requiresAuth: Bool { false }

    /// Bước 1 và gửi lại mã chờ server gửi email.
    var timeout: TimeInterval? {
        switch self {
        case .start, .resendOTP: return 60
        case .verify, .complete: return nil
        }
    }
}
