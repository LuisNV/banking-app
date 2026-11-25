import Alamofire
import Foundation

/// `{API_BASE_URL}/v1/auth/registrations`. Không cần token: `registrationId` là khoá của phiên.
enum RegistrationEndpoint: Endpoint {
    case start(RegistrationStartRequestDTO)
    case initiate(id: String, RegistrationInitiateRequestDTO)
    case verify(id: String, RegistrationVerifyRequestDTO)
    case resendOTP(id: String)
    case changeEmail(id: String, RegistrationEmailRequestDTO)
    case complete(id: String)
    case status(id: String)

    private static let base = "v1/auth/registrations"

    var path: String {
        switch self {
        case .start: return Self.base
        case .initiate(let id, _): return "\(Self.base)/\(id)/initiate"
        case .verify(let id, _): return "\(Self.base)/\(id)/verify"
        case .resendOTP(let id): return "\(Self.base)/\(id)/otp/resend"
        case .changeEmail(let id, _): return "\(Self.base)/\(id)/email"
        case .complete(let id): return "\(Self.base)/\(id)/complete"
        case .status(let id): return "\(Self.base)/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .start, .initiate, .verify, .resendOTP, .complete: return .post
        case .changeEmail: return .put
        case .status: return .get
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .start(let dto): return dto
        case .initiate(_, let dto): return dto
        case .verify(_, let dto): return dto
        case .changeEmail(_, let dto): return dto
        case .resendOTP, .complete, .status: return nil
        }
    }

    var requiresAuth: Bool { false }

    /// Bước gửi email (initiate, gửi lại, đổi email) chờ SMTP nên cho lâu hơn mặc định.
    var timeout: TimeInterval? {
        switch self {
        case .initiate, .resendOTP, .changeEmail: return 60
        case .start, .verify, .complete, .status: return nil
        }
    }
}
