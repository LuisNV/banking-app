import Foundation

struct LoginRequestDTO: Encodable {
    let username: String
    let password: String
}

struct RefreshTokenRequestDTO: Encodable {
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
    let user: UserDTO
}

extension AuthResponseDTO {
    func toDomain(now: Date = Date()) -> AuthSession {
        AuthSession(
            user: User(id: user.id, fullName: user.fullName, username: user.username),
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}
