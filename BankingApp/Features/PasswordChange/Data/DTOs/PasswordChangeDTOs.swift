import Foundation

/// Body `POST /v1/auth/password-changes`.
struct PasswordChangeStartRequestDTO: Encodable, Equatable {
    let currentPassword: String
    let newPassword: String
    let confirmPassword: String
    let logoutOtherDevices: Bool
}

/// Body `POST /{id}/verify`.
struct PasswordChangeVerifyRequestDTO: Encodable, Equatable {
    let code: String
}

/// `data` của bước 1 và của gửi lại mã (có thể rỗng).
struct PasswordChangeResponseDTO: DefaultDecodable, Equatable {
    var requestId: String?
    var email: String?
    var logoutOtherDevices: Bool?
    var otpExpiresAt: String?
    var resendAvailableAt: String?
    var remainingAttempts: Int?
    var expiresAt: String?

    init() {}

    init(
        requestId: String?,
        email: String? = nil,
        logoutOtherDevices: Bool? = nil,
        otpExpiresAt: String? = nil,
        resendAvailableAt: String? = nil,
        remainingAttempts: Int? = nil,
        expiresAt: String? = nil
    ) {
        self.requestId = requestId
        self.email = email
        self.logoutOtherDevices = logoutOtherDevices
        self.otpExpiresAt = otpExpiresAt
        self.resendAvailableAt = resendAvailableAt
        self.remainingAttempts = remainingAttempts
        self.expiresAt = expiresAt
    }

    /// - Parameters:
    ///   - fallbackId: id đã biết (gửi lại mã có thể không trả `requestId`).
    ///   - fallbackLogout: lựa chọn đã gửi ở bước 1.
    func toDomain(fallbackId: String?, fallbackLogout: Bool) -> PasswordChangeRequest? {
        guard let id = requestId ?? fallbackId, !id.isEmpty else { return nil }
        return PasswordChangeRequest(
            id: id,
            email: email,
            logoutOtherDevices: logoutOtherDevices ?? fallbackLogout,
            otpExpiresAt: otpExpiresAt.flatMap(RegistrationResponseDTO.parseDate),
            resendAvailableAt: resendAvailableAt.flatMap(RegistrationResponseDTO.parseDate),
            remainingAttempts: remainingAttempts,
            expiresAt: expiresAt.flatMap(RegistrationResponseDTO.parseDate)
        )
    }
}

/// `data` của bước 2.
struct PasswordChangeVerifyResponseDTO: DefaultDecodable, Equatable {
    var loggedOutOtherDevices: Bool?
    var revokedSessionCount: Int?

    init() {}

    init(loggedOutOtherDevices: Bool?, revokedSessionCount: Int?) {
        self.loggedOutOtherDevices = loggedOutOtherDevices
        self.revokedSessionCount = revokedSessionCount
    }

    func toDomain() -> PasswordChangeResult {
        PasswordChangeResult(
            loggedOutOtherDevices: loggedOutOtherDevices ?? false,
            revokedSessionCount: revokedSessionCount ?? 0
        )
    }
}
