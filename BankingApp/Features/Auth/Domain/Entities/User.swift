import Foundation

struct User: Equatable, Hashable {
    let id: String
    let fullName: String
    let username: String
}

struct AuthSession: Equatable {
    let user: User?
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

/// Cấu hình hiển thị cho màn hình đăng nhập.
struct LoginPreferences: Equatable {
    let rememberedUsername: String?
    let biometricType: BiometricType
    /// Có phiên đã lưu + máy hỗ trợ sinh trắc học.
    let canUseBiometricLogin: Bool
}
