import Foundation

/// Thông tin tài khoản của người đang đăng nhập (`GET v1/auth/me`).
struct UserProfile: Equatable {
    let id: String
    let fullName: String
    let email: String?
    let username: String?
    let phone: String?
    let birthDate: Date?
    let avatarURL: URL?
}
