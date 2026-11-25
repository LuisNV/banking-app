import Foundation

/// Bước tiếp theo server yêu cầu (`nextStep`).
enum RegistrationStep: String, Equatable {
    case setPassword = "SET_PASSWORD"
    case verifyEmail = "VERIFY_EMAIL"
    case complete = "COMPLETE"
    /// Phiên đã hoàn tất (không dùng lại được).
    case completed = "COMPLETED"
}

/// Trạng thái mã xác minh vừa gửi.
struct RegistrationOTP: Equatable {
    /// Mã hết hạn lúc nào.
    let expiresAt: Date?
    /// Lúc được bấm "Gửi lại mã".
    let resendAvailableAt: Date?
    let remainingAttempts: Int?
}

/// Phiên đăng ký. `id` (registrationId) là khoá của phiên, các API đăng ký không cần token.
struct RegistrationSession: Equatable {
    let id: String
    let nextStep: RegistrationStep
    /// Email của phiên (có khi server trả, vd. sau khi đổi email).
    var email: String?
    var otp: RegistrationOTP?
}

/// Kết quả bước 4: tài khoản đã tạo và đăng nhập luôn.
struct RegistrationResult: Equatable {
    let session: AuthSession
    let biometricEnabled: Bool
}

/// Dữ liệu lưu trên máy để mở lại app thì làm tiếp được phiên đăng ký.
struct SavedRegistration: Equatable {
    let id: String
    let info: RegistrationInfo
    let createdAt: Date

    /// Phiên sống 60 phút trên server.
    static let lifetime: TimeInterval = 60 * 60

    func isExpired(now: Date) -> Bool {
        now.timeIntervalSince(createdAt) >= Self.lifetime
    }
}
