import Foundation

protocol PasswordResetRemoteDataSource {
    func start(_ request: PasswordResetStartRequestDTO) async throws -> PasswordResetResponseDTO
    func resendOTP(resetId: String) async throws -> PasswordResetResponseDTO
    func verify(resetId: String, _ request: PasswordResetVerifyRequestDTO) async throws -> PasswordResetVerifyResponseDTO
    func complete(resetId: String, _ request: PasswordResetCompleteRequestDTO) async throws -> PasswordResetCompleteResponseDTO
}

final class PasswordResetRemoteDataSourceImpl: PasswordResetRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func start(_ request: PasswordResetStartRequestDTO) async throws -> PasswordResetResponseDTO {
        try await client.request(PasswordResetEndpoint.start(request), as: PasswordResetResponseDTO.self)
    }

    func resendOTP(resetId: String) async throws -> PasswordResetResponseDTO {
        try await client.request(PasswordResetEndpoint.resendOTP(resetId: resetId), as: PasswordResetResponseDTO.self)
    }

    func verify(resetId: String, _ request: PasswordResetVerifyRequestDTO) async throws -> PasswordResetVerifyResponseDTO {
        try await client.request(PasswordResetEndpoint.verify(resetId: resetId, request), as: PasswordResetVerifyResponseDTO.self)
    }

    func complete(resetId: String, _ request: PasswordResetCompleteRequestDTO) async throws -> PasswordResetCompleteResponseDTO {
        try await client.request(
            PasswordResetEndpoint.complete(resetId: resetId, request),
            as: PasswordResetCompleteResponseDTO.self
        )
    }
}

/// Backend giả (USE_MOCK_API = YES) theo luật của server:
/// mã đúng là "123456"; email/SĐT có chữ "unknown" coi như chưa đăng ký (vẫn trả 201, verify luôn 1010);
/// sai 5 lần → 1012; gửi lại cách 45 giây, tối đa 5 lần; phiên 15 phút; token 10 phút.
final class MockPasswordResetRemoteDataSource: PasswordResetRemoteDataSource {
    static let validCode = "123456"

    private struct Session {
        let identifier: String
        let exists: Bool
        let createdAt: Date
        var sentAt: Date
        var sendCount = 1
        var failedCodes = 0
        var token: String?
    }

    private var sessions: [String: Session] = [:]
    private let delay: Duration
    private let now: () -> Date

    init(delay: Duration = .milliseconds(700), now: @escaping () -> Date = Date.init) {
        self.delay = delay
        self.now = now
    }

    func start(_ request: PasswordResetStartRequestDTO) async throws -> PasswordResetResponseDTO {
        try await Task.sleep(for: delay)
        let id = UUID().uuidString.lowercased()
        let session = Session(
            identifier: request.identifier,
            exists: !request.identifier.contains("unknown"),
            createdAt: now(),
            sentAt: now()
        )
        sessions[id] = session
        return response(id, session)
    }

    func resendOTP(resetId: String) async throws -> PasswordResetResponseDTO {
        try await Task.sleep(for: delay / 2)
        var session = try find(resetId)
        guard session.token == nil else { throw Self.error(409, 409, "Mã đã được xác minh") }
        let wait = 45 - Int(now().timeIntervalSince(session.sentAt))
        if wait > 0 { throw Self.error(1013, 429, "Vui lòng chờ \(wait) giây trước khi gửi lại mã") }
        guard session.sendCount < 5 else { throw Self.error(1014, 429, "Đã gửi mã quá nhiều lần") }
        session.sendCount += 1
        session.sentAt = now()
        session.failedCodes = 0
        sessions[resetId] = session
        return response(resetId, session)
    }

    func verify(resetId: String, _ request: PasswordResetVerifyRequestDTO) async throws -> PasswordResetVerifyResponseDTO {
        try await Task.sleep(for: delay)
        var session = try find(resetId)
        guard session.failedCodes < 5 else { throw Self.error(1012, 429, "Nhập sai quá nhiều lần, vui lòng gửi lại mã mới") }
        guard now().timeIntervalSince(session.sentAt) <= 600 else {
            throw Self.error(1011, 400, "Mã xác thực đã hết hạn, vui lòng gửi lại mã")
        }
        guard session.exists, request.code == Self.validCode else {
            session.failedCodes += 1
            sessions[resetId] = session
            throw Self.error(1010, 400, "Mã xác thực không đúng. Bạn còn \(5 - session.failedCodes) lần thử")
        }
        let token = UUID().uuidString
        session.token = token
        sessions[resetId] = session
        return PasswordResetVerifyResponseDTO(
            resetToken: token,
            resetTokenExpiresAt: ISO8601DateFormatter().string(from: now().addingTimeInterval(600)),
            email: "de••@tingting.vn"
        )
    }

    func complete(resetId: String, _ request: PasswordResetCompleteRequestDTO) async throws -> PasswordResetCompleteResponseDTO {
        try await Task.sleep(for: delay)
        let session = try find(resetId)
        guard let token = session.token else { throw Self.error(1023, 409, "Chưa xác minh mã") }
        guard token == request.resetToken else { throw Self.error(1024, 403, "Phiên xác minh không hợp lệ") }
        guard request.newPassword == request.confirmPassword else { throw Self.error(1008, 400, "Mật khẩu nhập lại không khớp") }
        guard PasswordEvaluation.evaluate(request.newPassword).meetsRequirements else {
            throw Self.error(1009, 400, "Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và ít nhất 1 chữ số")
        }
        sessions[resetId] = nil
        return PasswordResetCompleteResponseDTO(revokedSessionCount: 2, notifiedEmail: "de••@tingting.vn", biometricDisabled: true)
    }

    private func find(_ id: String) throws -> Session {
        guard let session = sessions[id] else { throw Self.error(1021, 404, "Không tìm thấy yêu cầu đặt lại mật khẩu") }
        guard now().timeIntervalSince(session.createdAt) <= 900 else {
            throw Self.error(1022, 410, "Yêu cầu đặt lại mật khẩu đã hết hạn, vui lòng thực hiện lại")
        }
        return session
    }

    private func response(_ id: String, _ session: Session) -> PasswordResetResponseDTO {
        let iso = ISO8601DateFormatter()
        return PasswordResetResponseDTO(
            resetId: id,
            identifierType: session.identifier.contains("@") ? "EMAIL" : "PHONE",
            destination: "de••@tingting.vn",
            otpExpiresAt: iso.string(from: session.sentAt.addingTimeInterval(600)),
            resendAvailableAt: iso.string(from: session.sentAt.addingTimeInterval(45)),
            remainingAttempts: 5 - session.failedCodes,
            expiresAt: iso.string(from: session.createdAt.addingTimeInterval(900))
        )
    }

    private static func error(_ code: Int, _ status: Int, _ message: String) -> NetworkError {
        .api(code: code, httpStatus: status, message: message, traceId: nil)
    }
}
