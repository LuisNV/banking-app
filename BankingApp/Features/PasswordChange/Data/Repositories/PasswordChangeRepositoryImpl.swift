import Foundation

final class PasswordChangeRepositoryImpl: PasswordChangeRepository {
    private let remote: PasswordChangeRemoteDataSource

    init(remote: PasswordChangeRemoteDataSource) {
        self.remote = remote
    }

    func start(currentPassword: String, newPassword: String, confirmPassword: String, logoutOtherDevices: Bool)
        async throws -> PasswordChangeRequest {
        let dto = PasswordChangeStartRequestDTO(
            currentPassword: currentPassword,
            newPassword: newPassword,
            confirmPassword: confirmPassword,
            logoutOtherDevices: logoutOtherDevices
        )
        do {
            guard let request = try await remote.start(dto).toDomain(fallbackId: nil, fallbackLogout: logoutOtherDevices) else {
                throw PasswordChangeError.unknown
            }
            return request
        } catch {
            throw Self.map(error, in: .start)
        }
    }

    func resendCode(requestId: String) async throws -> PasswordChangeRequest? {
        do {
            return try await remote.resendOTP(requestId: requestId).toDomain(fallbackId: requestId, fallbackLogout: false)
        } catch {
            throw Self.map(error, in: .resend)
        }
    }

    func verify(requestId: String, code: String) async throws -> PasswordChangeResult {
        do {
            return try await remote.verify(requestId: requestId, PasswordChangeVerifyRequestDTO(code: code)).toDomain()
        } catch {
            throw Self.map(error, in: .verify)
        }
    }

    /// API đang gọi: 1014 nghĩa khác nhau ở bước 1 và lúc gửi lại mã.
    enum Operation { case start, resend, verify }

    /// Mã lỗi theo `ErrorCode.java`.
    static func map(_ error: Error, in operation: Operation) -> PasswordChangeError {
        if let changeError = error as? PasswordChangeError { return changeError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        case .unauthorized:
            // AuthInterceptor đã thử refresh mà không được.
            return .sessionExpired
        case .api(let code, let httpStatus, let message, _):
            switch code {
            case 1002: return .wrongCurrentPassword(message: message)
            case 1008: return .passwordMismatch(message: message)
            case 1009: return .weakPassword(message: message)
            case 1010: return .invalidCode(message: message)
            case 1011: return .codeExpired(message: message)
            case 1012: return .tooManyAttempts(message: message)
            case 1013: return .resendTooSoon(message: message)
            case 1014:
                // Lúc gửi lại mã, câu mặc định của server nhắc tới "phiên đăng ký": dùng câu của app.
                return operation == .resend ? .sendLimitReached : .tooManyRequests(message: message)
            case 1016: return .sessionUnknown(message: message)
            case 1017: return .sameAsCurrent(message: message)
            case 1018: return .locked(message: message)
            case 1019: return .requestNotFound(message: message)
            case 1020: return .requestExpired(message: message)
            default: break
            }
            switch httpStatus {
            case 401: return .sessionExpired
            case 404: return .requestNotFound(message: message)
            case 410: return .requestExpired(message: message)
            case 502, 503: return .emailDeliveryFailed
            default: return message.isEmpty ? .unknown : .api(message: message)
            }
        case .server(let statusCode) where statusCode == 404:
            return .requestNotFound(message: nil)
        case .server(let statusCode) where statusCode == 410:
            return .requestExpired(message: nil)
        case .server(let statusCode) where statusCode == 502 || statusCode == 503:
            return .emailDeliveryFailed
        case .noConnection, .timeout: return .network
        case .server, .decoding, .unknown: return .unknown
        }
    }
}
