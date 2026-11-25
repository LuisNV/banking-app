import Foundation

// MARK: - Requests (JSON camelCase)

/// `POST /v1/auth/registrations`
struct RegistrationStartRequestDTO: Encodable, Equatable {
    let fullName: String
    let email: String
    let phone: String
    /// "yyyy-MM-dd", không bắt buộc.
    let dateOfBirth: String?
}

/// `POST /v1/auth/registrations/{id}/initiate`
struct RegistrationInitiateRequestDTO: Encodable, Equatable {
    let password: String
    let confirmPassword: String
    let biometricEnabled: Bool
}

/// `POST /v1/auth/registrations/{id}/verify`
struct RegistrationVerifyRequestDTO: Encodable, Equatable {
    let code: String
}

/// `PUT /v1/auth/registrations/{id}/email`
struct RegistrationEmailRequestDTO: Encodable, Equatable {
    let email: String
}

// MARK: - Responses

/// `data` của các bước 1–3, gửi lại mã, đổi email và xem trạng thái.
/// Mọi trường đều không bắt buộc để chịu được khác biệt nhỏ giữa các API.
struct RegistrationResponseDTO: Decodable, Equatable {
    var registrationId: String?
    var status: String?
    var nextStep: String?
    var email: String?
    /// ISO 8601.
    var otpExpiresAt: String?
    var resendAvailableAt: String?
    var remainingAttempts: Int?

    init(
        registrationId: String? = nil,
        status: String? = nil,
        nextStep: String? = nil,
        email: String? = nil,
        otpExpiresAt: String? = nil,
        resendAvailableAt: String? = nil,
        remainingAttempts: Int? = nil
    ) {
        self.registrationId = registrationId
        self.status = status
        self.nextStep = nextStep
        self.email = email
        self.otpExpiresAt = otpExpiresAt
        self.resendAvailableAt = resendAvailableAt
        self.remainingAttempts = remainingAttempts
    }

    private enum CodingKeys: String, CodingKey {
        case registrationId, id, status, nextStep, email
        case otpExpiresAt, resendAvailableAt, remainingAttempts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        registrationId = Self.flexibleString(container, .registrationId) ?? Self.flexibleString(container, .id)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        nextStep = try container.decodeIfPresent(String.self, forKey: .nextStep)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        otpExpiresAt = try container.decodeIfPresent(String.self, forKey: .otpExpiresAt)
        resendAvailableAt = try container.decodeIfPresent(String.self, forKey: .resendAvailableAt)
        remainingAttempts = try container.decodeIfPresent(Int.self, forKey: .remainingAttempts)
    }

    /// `id` có thể là chuỗi (UUID) hoặc số.
    private static func flexibleString(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let text = try? container.decode(String.self, forKey: key) { return text }
        if let number = try? container.decode(Int.self, forKey: key) { return String(number) }
        return nil
    }

    /// - Parameter fallbackId: id đã biết (các API sau bước 1 có thể không trả lại `registrationId`).
    func toDomain(fallbackId: String?) throws -> RegistrationSession {
        guard let id = registrationId ?? fallbackId, !id.isEmpty else { throw NetworkError.decoding }
        let otp: RegistrationOTP? = (otpExpiresAt != nil || resendAvailableAt != nil || remainingAttempts != nil)
            ? RegistrationOTP(
                expiresAt: otpExpiresAt.flatMap(Self.parseDate),
                resendAvailableAt: resendAvailableAt.flatMap(Self.parseDate),
                remainingAttempts: remainingAttempts
            )
            : nil
        return RegistrationSession(id: id, nextStep: step, email: email, otp: otp)
    }

    /// Ưu tiên `nextStep`; thiếu thì suy ra từ `status`.
    var step: RegistrationStep {
        if let nextStep, let step = RegistrationStep(rawValue: nextStep.uppercased()) { return step }
        switch status?.uppercased() {
        case "OTP_SENT": return .verifyEmail
        case "VERIFIED": return .complete
        case "COMPLETED": return .completed
        default: return .setPassword
        }
    }

    static func parseDate(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        // "2026-11-25T10:15:30" (không múi giờ): coi là giờ máy.
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            local.dateFormat = format
            if let date = local.date(from: text) { return date }
        }
        return nil
    }
}

/// `data` của bước 4 (`/complete`).
struct RegistrationCompleteDTO: Decodable, Equatable {
    struct Tokens: Decodable, Equatable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String?
        let expiresIn: Int?
    }

    let user: UserProfileDTO?
    let biometricEnabled: Bool?
    let tokens: Tokens

    func toDomain(now: Date = Date()) -> RegistrationResult {
        let profile = user?.toDomain()
        let user = profile.map {
            User(id: $0.id, fullName: $0.fullName, username: $0.email ?? $0.username ?? "")
        }
        return RegistrationResult(
            session: AuthSession(
                user: user,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresAt: now.addingTimeInterval(TimeInterval(tokens.expiresIn ?? 900))
            ),
            biometricEnabled: biometricEnabled ?? false
        )
    }
}
