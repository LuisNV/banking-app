import Foundation

protocol PasswordChangeRemoteDataSource {
    func start(_ request: PasswordChangeStartRequestDTO) async throws -> PasswordChangeResponseDTO
    func resendOTP(requestId: String) async throws -> PasswordChangeResponseDTO
    func verify(requestId: String, _ request: PasswordChangeVerifyRequestDTO) async throws -> PasswordChangeVerifyResponseDTO
}

final class PasswordChangeRemoteDataSourceImpl: PasswordChangeRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func start(_ request: PasswordChangeStartRequestDTO) async throws -> PasswordChangeResponseDTO {
        try await client.request(PasswordChangeEndpoint.start(request), as: PasswordChangeResponseDTO.self)
    }

    func resendOTP(requestId: String) async throws -> PasswordChangeResponseDTO {
        try await client.request(PasswordChangeEndpoint.resendOTP(requestId: requestId), as: PasswordChangeResponseDTO.self)
    }

    func verify(requestId: String, _ request: PasswordChangeVerifyRequestDTO) async throws -> PasswordChangeVerifyResponseDTO {
        try await client.request(
            PasswordChangeEndpoint.verify(requestId: requestId, request),
            as: PasswordChangeVerifyResponseDTO.self
        )
    }
}

/// Backend giả (USE_MOCK_API = YES) theo luật của server:
/// mật khẩu hiện tại đúng là "123456"; sai 5 lần → khoá 15 phút; mã đúng là "123456";
/// sai mã 5 lần; gửi lại cách 45 giây, tối đa 5 lần mỗi yêu cầu; yêu cầu hết hạn sau 15 phút.
final class MockPasswordChangeRemoteDataSource: PasswordChangeRemoteDataSource {
    static let currentPassword = MockAuthRemoteDataSource.validPassword
    static let validCode = "123456"

    private struct Pending {
        let logoutOtherDevices: Bool
        let createdAt: Date
        var sentAt: Date
        var sendCount = 1
        var failedCodes = 0
    }

    private var pending: [String: Pending] = [:]
    private var failedPasswords = 0
    private var lockedUntil: Date?
    private let delay: Duration
    private let now: () -> Date

    init(delay: Duration = .milliseconds(700), now: @escaping () -> Date = Date.init) {
        self.delay = delay
        self.now = now
    }

    func start(_ request: PasswordChangeStartRequestDTO) async throws -> PasswordChangeResponseDTO {
        try await Task.sleep(for: delay)
        if let lockedUntil, lockedUntil > now() {
            let minutes = Int((lockedUntil.timeIntervalSince(now()) / 60).rounded(.up))
            throw Self.error(1018, 429, "Bạn đã nhập sai mật khẩu quá nhiều lần. Vui lòng thử lại sau \(minutes) phút")
        }
        guard request.currentPassword == Self.currentPassword else {
            failedPasswords += 1
            if failedPasswords >= 5 {
                failedPasswords = 0
                lockedUntil = now().addingTimeInterval(15 * 60)
                throw Self.error(1018, 429, "Bạn đã nhập sai mật khẩu quá nhiều lần. Vui lòng thử lại sau 15 phút")
            }
            throw Self.error(1002, 400, "Mật khẩu hiện tại không đúng. Bạn còn \(5 - failedPasswords) lần thử")
        }
        failedPasswords = 0
        guard request.newPassword == request.confirmPassword else {
            throw Self.error(1008, 400, "Mật khẩu nhập lại không khớp")
        }
        guard request.newPassword != request.currentPassword else {
            throw Self.error(400, 400, "Mật khẩu mới phải khác mật khẩu hiện tại")
        }
        // Yêu cầu cũ bị huỷ, mã cũ hết hiệu lực.
        pending.removeAll()
        let id = UUID().uuidString.lowercased()
        let item = Pending(logoutOtherDevices: request.logoutOtherDevices, createdAt: now(), sentAt: now())
        pending[id] = item
        return response(id, item)
    }

    func resendOTP(requestId: String) async throws -> PasswordChangeResponseDTO {
        try await Task.sleep(for: delay / 2)
        var item = try find(requestId)
        let wait = 45 - Int(now().timeIntervalSince(item.sentAt))
        if wait > 0 { throw Self.error(1013, 429, "Vui lòng chờ \(wait) giây") }
        guard item.sendCount < 5 else { throw Self.error(1014, 429, "Bạn đã gửi lại mã quá nhiều lần") }
        item.sendCount += 1
        item.sentAt = now()
        item.failedCodes = 0
        pending[requestId] = item
        return response(requestId, item)
    }

    func verify(requestId: String, _ request: PasswordChangeVerifyRequestDTO) async throws -> PasswordChangeVerifyResponseDTO {
        try await Task.sleep(for: delay)
        var item = try find(requestId)
        guard item.failedCodes < 5 else { throw Self.error(1012, 429, "Bạn đã nhập sai mã quá 5 lần") }
        guard now().timeIntervalSince(item.sentAt) <= 600 else { throw Self.error(1011, 400, "Mã đã hết hạn") }
        guard request.code == Self.validCode else {
            item.failedCodes += 1
            pending[requestId] = item
            throw Self.error(1010, 400, "Mã không đúng. Bạn còn \(5 - item.failedCodes) lần thử")
        }
        pending[requestId] = nil
        return PasswordChangeVerifyResponseDTO(
            loggedOutOtherDevices: item.logoutOtherDevices,
            revokedSessionCount: item.logoutOtherDevices ? 2 : 0
        )
    }

    private func find(_ id: String) throws -> Pending {
        guard let item = pending[id], now().timeIntervalSince(item.createdAt) <= 15 * 60 else {
            throw Self.error(410, 410, "Yêu cầu đổi mật khẩu đã hết hạn")
        }
        return item
    }

    private func response(_ id: String, _ item: Pending) -> PasswordChangeResponseDTO {
        let iso = ISO8601DateFormatter()
        return PasswordChangeResponseDTO(
            requestId: id,
            email: "demo@tingting.vn",
            logoutOtherDevices: item.logoutOtherDevices,
            otpExpiresAt: iso.string(from: item.sentAt.addingTimeInterval(600)),
            resendAvailableAt: iso.string(from: item.sentAt.addingTimeInterval(45)),
            remainingAttempts: 5 - item.failedCodes,
            expiresAt: iso.string(from: item.createdAt.addingTimeInterval(900))
        )
    }

    private static func error(_ code: Int, _ status: Int, _ message: String) -> NetworkError {
        .api(code: code, httpStatus: status, message: message, traceId: nil)
    }
}
