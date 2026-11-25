import Foundation

/// Body: `{"identifier", "password", "deviceId", "deviceName", "platform"}`.
struct LoginRequestDTO: Encodable, Equatable {
    /// Email hoặc số điện thoại.
    let identifier: String
    let password: String
    /// UUID cố định của máy (`DeviceInfo.id`).
    let deviceId: String
    /// Vd. "iPhone 15 Pro".
    let deviceName: String
    /// Vd. "iOS 18.1".
    let platform: String
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
