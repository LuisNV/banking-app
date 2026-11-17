import Alamofire
import Foundation

enum AuthEndpoint: Endpoint {
    case login(LoginRequestDTO)
    case refresh(RefreshTokenRequestDTO)
    case logout

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
        case .logout: return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .refresh: return false
        case .logout: return true
        }
    }
}
