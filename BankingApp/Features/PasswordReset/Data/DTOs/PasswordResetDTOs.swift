import Foundation

struct PasswordResetStartRequestDTO: Encodable, Equatable {
    let identifier: String
}

struct PasswordResetVerifyRequestDTO: Encodable, Equatable {
    let code: String
}

struct PasswordResetCompleteRequestDTO: Encodable, Equatable {
    let resetToken: String
    let newPassword: String
    let confirmPassword: String
}

/// `data` của bước 1 và gửi lại mã.
struct PasswordResetResponseDTO: DefaultDecodable, Equatable {
    var resetId: String?
    var identifierType: String?
    var destination: String?
    var otpExpiresAt: String?
    var resendAvailableAt: String?
    var remainingAttempts: Int?
    var expiresAt: String?

    init() {}

    init(
        resetId: String?,
        identifierType: String? = nil,
        destination: String? = nil,
        otpExpiresAt: String? = nil,
        resendAvailableAt: String? = nil,
        remainingAttempts: Int? = nil,
        expiresAt: String? = nil
    ) {
        self.resetId = resetId
        self.identifierType = identifierType
        self.destination = destination
        self.otpExpiresAt = otpExpiresAt
        self.resendAvailableAt = resendAvailableAt
        self.remainingAttempts = remainingAttempts
        self.expiresAt = expiresAt
    }

    func toDomain(fallbackId: String?) -> PasswordResetRequest? {
        guard let id = resetId ?? fallbackId, !id.isEmpty else { return nil }
        return PasswordResetRequest(
            id: id,
            identifierType: identifierType,
            destination: destination,
            otpExpiresAt: otpExpiresAt.flatMap(RegistrationResponseDTO.parseDate),
            resendAvailableAt: resendAvailableAt.flatMap(RegistrationResponseDTO.parseDate),
            remainingAttempts: remainingAttempts,
            expiresAt: expiresAt.flatMap(RegistrationResponseDTO.parseDate)
        )
    }
}

/// `data` của bước xác minh mã.
struct PasswordResetVerifyResponseDTO: Decodable, Equatable {
    let resetToken: String
    var resetTokenExpiresAt: String?
    var email: String?

    func toDomain() -> PasswordResetVerification {
        PasswordResetVerification(
            token: resetToken,
            tokenExpiresAt: resetTokenExpiresAt.flatMap(RegistrationResponseDTO.parseDate),
            email: email
        )
    }
}

/// `data` của bước đặt mật khẩu mới.
struct PasswordResetCompleteResponseDTO: DefaultDecodable, Equatable {
    var revokedSessionCount: Int?
    var notifiedEmail: String?
    var biometricDisabled: Bool?

    init() {}

    init(revokedSessionCount: Int?, notifiedEmail: String?, biometricDisabled: Bool?) {
        self.revokedSessionCount = revokedSessionCount
        self.notifiedEmail = notifiedEmail
        self.biometricDisabled = biometricDisabled
    }

    func toDomain() -> PasswordResetResult {
        PasswordResetResult(
            revokedSessionCount: revokedSessionCount ?? 0,
            notifiedEmail: notifiedEmail,
            biometricDisabled: biometricDisabled ?? true
        )
    }
}
