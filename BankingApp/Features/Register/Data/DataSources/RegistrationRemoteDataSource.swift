import Foundation

protocol RegistrationRemoteDataSource {
    func start(_ request: RegistrationStartRequestDTO) async throws -> RegistrationResponseDTO
    func initiate(id: String, _ request: RegistrationInitiateRequestDTO) async throws -> RegistrationResponseDTO
    func verify(id: String, _ request: RegistrationVerifyRequestDTO) async throws -> RegistrationResponseDTO
    func resendOTP(id: String) async throws -> RegistrationResponseDTO
    func changeEmail(id: String, _ request: RegistrationEmailRequestDTO) async throws -> RegistrationResponseDTO
    func complete(id: String) async throws -> RegistrationCompleteDTO
    func status(id: String) async throws -> RegistrationResponseDTO
}

final class RegistrationRemoteDataSourceImpl: RegistrationRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func start(_ request: RegistrationStartRequestDTO) async throws -> RegistrationResponseDTO {
        try await client.request(RegistrationEndpoint.start(request), as: RegistrationResponseDTO.self)
    }

    func initiate(id: String, _ request: RegistrationInitiateRequestDTO) async throws -> RegistrationResponseDTO {
        try await client.request(RegistrationEndpoint.initiate(id: id, request), as: RegistrationResponseDTO.self)
    }

    func verify(id: String, _ request: RegistrationVerifyRequestDTO) async throws -> RegistrationResponseDTO {
        try await client.request(RegistrationEndpoint.verify(id: id, request), as: RegistrationResponseDTO.self)
    }

    func resendOTP(id: String) async throws -> RegistrationResponseDTO {
        try await client.request(RegistrationEndpoint.resendOTP(id: id), as: RegistrationResponseDTO.self)
    }

    func changeEmail(id: String, _ request: RegistrationEmailRequestDTO) async throws -> RegistrationResponseDTO {
        try await client.request(RegistrationEndpoint.changeEmail(id: id, request), as: RegistrationResponseDTO.self)
    }

    func complete(id: String) async throws -> RegistrationCompleteDTO {
        try await client.request(RegistrationEndpoint.complete(id: id), as: RegistrationCompleteDTO.self)
    }

    func status(id: String) async throws -> RegistrationResponseDTO {
        try await client.request(RegistrationEndpoint.status(id: id), as: RegistrationResponseDTO.self)
    }
}

/// Backend giả (USE_MOCK_API = YES), mô phỏng đúng luật của server:
/// - Email `taken@example.com` → 1003, số `0000000000` → 1004.
/// - Mã đúng là `123456`; sai 5 lần → 1012; gửi lại phải chờ 45 giây (1013), tối đa 5 lần/phiên (1014).
final class MockRegistrationRemoteDataSource: RegistrationRemoteDataSource {
    static let validCode = "123456"
    static let takenEmail = "taken@example.com"
    static let takenPhone = "0000000000"

    private struct Session {
        var info: RegistrationStartRequestDTO
        var status = "CREATED"
        var biometricEnabled = false
        var failedAttempts = 0
        var sendCount = 0
        var lastSentAt: Date?
    }

    private var sessions: [String: Session] = [:]
    private let delay: Duration
    private let now: () -> Date

    init(delay: Duration = .milliseconds(700), now: @escaping () -> Date = Date.init) {
        self.delay = delay
        self.now = now
    }

    func start(_ request: RegistrationStartRequestDTO) async throws -> RegistrationResponseDTO {
        try await Task.sleep(for: delay)
        if request.email == Self.takenEmail { throw Self.error(1003, 409, "Email đã được sử dụng") }
        if request.phone == Self.takenPhone { throw Self.error(1004, 409, "Số điện thoại đã được sử dụng") }
        let id = UUID().uuidString.lowercased()
        sessions[id] = Session(info: request)
        return RegistrationResponseDTO(registrationId: id, status: "CREATED", nextStep: "SET_PASSWORD", email: request.email)
    }

    func initiate(id: String, _ request: RegistrationInitiateRequestDTO) async throws -> RegistrationResponseDTO {
        try await Task.sleep(for: delay)
        var session = try find(id)
        guard ["CREATED", "OTP_SENT"].contains(session.status) else { throw Self.error(1007, 409, "Sai bước đăng ký") }
        guard request.password == request.confirmPassword else { throw Self.error(1008, 400, "Mật khẩu nhập lại không khớp") }
        guard PasswordEvaluation.evaluate(request.password).meetsRequirements else {
            throw Self.error(1009, 400, "Mật khẩu yếu")
        }
        session.biometricEnabled = request.biometricEnabled
        if session.status == "CREATED" {
            try send(&session)
            session.status = "OTP_SENT"
        }
        sessions[id] = session
        return response(id, session)
    }

    func verify(id: String, _ request: RegistrationVerifyRequestDTO) async throws -> RegistrationResponseDTO {
        try await Task.sleep(for: delay)
        var session = try find(id)
        if session.status == "VERIFIED" { return response(id, session) }
        guard session.status == "OTP_SENT" else { throw Self.error(1007, 409, "Sai bước đăng ký") }
        guard session.failedAttempts < 5 else { throw Self.error(1012, 429, "Bạn đã nhập sai quá 5 lần, vui lòng gửi lại mã") }
        if let sentAt = session.lastSentAt, now().timeIntervalSince(sentAt) > 600 {
            throw Self.error(1011, 400, "Mã đã hết hạn")
        }
        guard request.code == Self.validCode else {
            session.failedAttempts += 1
            sessions[id] = session
            throw Self.error(1010, 400, "Mã không đúng. Bạn còn \(5 - session.failedAttempts) lần thử")
        }
        session.status = "VERIFIED"
        sessions[id] = session
        return response(id, session)
    }

    func resendOTP(id: String) async throws -> RegistrationResponseDTO {
        try await Task.sleep(for: delay / 2)
        var session = try find(id)
        guard session.status == "OTP_SENT" else { throw Self.error(1007, 409, "Sai bước đăng ký") }
        if let sentAt = session.lastSentAt {
            let wait = 45 - Int(now().timeIntervalSince(sentAt))
            if wait > 0 { throw Self.error(1013, 429, "Vui lòng chờ \(wait) giây") }
        }
        try send(&session)
        sessions[id] = session
        return response(id, session)
    }

    func changeEmail(id: String, _ request: RegistrationEmailRequestDTO) async throws -> RegistrationResponseDTO {
        try await Task.sleep(for: delay)
        var session = try find(id)
        guard session.status == "OTP_SENT" else { throw Self.error(1007, 409, "Sai bước đăng ký") }
        if request.email == Self.takenEmail { throw Self.error(1003, 409, "Email đã được sử dụng") }
        session.info = RegistrationStartRequestDTO(
            fullName: session.info.fullName, email: request.email,
            phone: session.info.phone, dateOfBirth: session.info.dateOfBirth
        )
        try send(&session)
        sessions[id] = session
        return response(id, session)
    }

    func complete(id: String) async throws -> RegistrationCompleteDTO {
        try await Task.sleep(for: delay)
        var session = try find(id)
        guard session.status == "VERIFIED" else { throw Self.error(1007, 409, "Bạn chưa xác minh email") }
        session.status = "COMPLETED"
        sessions[id] = session
        return RegistrationCompleteDTO(
            user: UserProfileDTO(
                id: "u_new", fullName: session.info.fullName, email: session.info.email, username: nil,
                phone: session.info.phone, birthDate: session.info.dateOfBirth, avatarUrl: nil,
                emailVerified: true
            ),
            biometricEnabled: session.biometricEnabled,
            tokens: .init(accessToken: UUID().uuidString, refreshToken: UUID().uuidString, tokenType: "Bearer", expiresIn: 900)
        )
    }

    func status(id: String) async throws -> RegistrationResponseDTO {
        try await Task.sleep(for: delay / 2)
        let session = try find(id)
        return response(id, session)
    }

    // MARK: Private

    private func find(_ id: String) throws -> Session {
        guard let session = sessions[id] else { throw Self.error(1005, 404, "Không tìm thấy phiên đăng ký") }
        return session
    }

    private func send(_ session: inout Session) throws {
        guard session.sendCount < 5 else { throw Self.error(1014, 429, "Bạn đã gửi mã quá nhiều lần") }
        session.sendCount += 1
        session.failedAttempts = 0
        session.lastSentAt = now()
    }

    private func response(_ id: String, _ session: Session) -> RegistrationResponseDTO {
        let step: String
        switch session.status {
        case "CREATED": step = "SET_PASSWORD"
        case "OTP_SENT": step = "VERIFY_EMAIL"
        case "VERIFIED": step = "COMPLETE"
        default: step = "COMPLETED"
        }
        let iso = ISO8601DateFormatter()
        let sentAt = session.lastSentAt
        return RegistrationResponseDTO(
            registrationId: id,
            status: session.status,
            nextStep: step,
            email: session.info.email,
            otpExpiresAt: sentAt.map { iso.string(from: $0.addingTimeInterval(600)) },
            resendAvailableAt: sentAt.map { iso.string(from: $0.addingTimeInterval(45)) },
            remainingAttempts: session.status == "OTP_SENT" ? 5 - session.failedAttempts : nil
        )
    }

    private static func error(_ code: Int, _ status: Int, _ message: String) -> NetworkError {
        .api(code: code, httpStatus: status, message: message, traceId: nil)
    }
}
