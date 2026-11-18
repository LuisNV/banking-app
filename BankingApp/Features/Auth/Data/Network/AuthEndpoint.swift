import Alamofire
import Foundation

enum AuthEndpoint: Endpoint {
    case login(LoginRequestDTO)
    case refresh(RefreshTokenRequestDTO)
    case logout(LogoutRequestDTO)

    var path: String {
        switch self {
        case .login: return "v1/auth/login"
        case .refresh: return "v1/auth/refresh"
        case .logout: return "v1/auth/logout"
        }
    }

    var method: HTTPMethod { .post }

    var body: (any Encodable)? {
        switch self {
        case .login(let dto): return dto
        case .refresh(let dto): return dto
        case .logout(let dto): return dto
        }
    }

    var requiresAuth: Bool {
        switch self {
        // Cả ba endpoint xác thực bằng body, không cần Bearer token.
        // Riêng refresh bắt buộc không gắn token để AuthInterceptor không retry đệ quy.
        case .login, .refresh, .logout: return false
        }
    }
}
