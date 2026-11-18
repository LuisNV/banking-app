import Foundation

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

/// Body: `{"refreshToken": "..."}`
struct RefreshTokenRequestDTO: Encodable {
    let refreshToken: String
}

/// Body: `{"refreshToken": "..."}`. Server thu hồi refresh token này.
struct LogoutRequestDTO: Encodable {
    let refreshToken: String
}

struct UserDTO: Decodable {
    let id: String
    let fullName: String
    let username: String
}

struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    /// Số giây đến khi access token hết hạn.
    let expiresIn: Int
    let tokenType: String
    let user: UserDTO?
}

extension AuthResponseDTO {
    func toDomain(now: Date = Date()) -> AuthSession {
        AuthSession(
            user: user.map { User(id: $0.id, fullName: $0.fullName, username: $0.username) },
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}
