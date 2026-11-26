import Foundation

final class PasswordResetRepositoryImpl: PasswordResetRepository {
    private let remote: PasswordResetRemoteDataSource

    init(remote: PasswordResetRemoteDataSource) {
        self.remote = remote
    }

    func start(identifier: String) async throws -> PasswordResetRequest {
        do {
            guard let request = try await remote.start(PasswordResetStartRequestDTO(identifier: identifier))
                .toDomain(fallbackId: nil) else { throw PasswordResetError.unknown }
            return request
        } catch {
            throw Self.map(error, in: .start)
        }
    }

    func resendCode(resetId: String) async throws -> PasswordResetRequest? {
        do {
            return try await remote.resendOTP(resetId: resetId).toDomain(fallbackId: resetId)
        } catch {
            throw Self.map(error, in: .resend)
        }
    }

    func verify(resetId: String, code: String) async throws -> PasswordResetVerification {
        do {
            return try await remote.verify(resetId: resetId, PasswordResetVerifyRequestDTO(code: code)).toDomain()
        } catch {
            throw Self.map(error, in: .verify)
        }
    }

    func complete(resetId: String, token: String, newPassword: String, confirmPassword: String)
        async throws -> PasswordResetResult {
        let dto = PasswordResetCompleteRequestDTO(
            resetToken: token, newPassword: newPassword, confirmPassword: confirmPassword
        )
        do {
            return try await remote.complete(resetId: resetId, dto).toDomain()
        } catch {
            throw Self.map(error, in: .complete)
        }
    }

    /// API đang gọi: 1014 và 409 mang nghĩa khác nhau tuỳ bước.
    enum Operation { case start, resend, verify, complete }

    static func map(_ error: Error, in operation: Operation) -> PasswordResetError {
        if let resetError = error as? PasswordResetError { return resetError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        case .api(let code, let httpStatus, let message, _):
            switch code {
            case 1008: return .passwordMismatch(message: message)
            case 1009: return .weakPassword(message: message)
            case 1010: return .invalidCode(message: message)
            case 1011: return .codeExpired(message: message)
            case 1012: return .tooManyAttempts(message: message)
            case 1013: return .resendTooSoon(message: message)
            case 1014: return operation == .resend ? .sendLimitReached : .tooManyRequests(message: message)
            case 1017: return .sameAsCurrent(message: message)
            case 1021: return .notFound(message: message)
            case 1022: return .expired(message: message)
            case 1023: return .notVerified
            case 1024: return .tokenInvalid
            case 1025: return .invalidIdentifier(message: message)
            default: break
            }
            switch httpStatus {
            case 409 where operation == .resend: return .alreadyVerified
            case 404: return .notFound(message: message)
            case 410: return .expired(message: message)
            case 400 where operation == .start: return .invalidIdentifier(message: message)
            default: return message.isEmpty ? .unknown : .api(message: message)
            }
        case .server(let statusCode) where statusCode == 404:
            return .notFound(message: nil)
        case .server(let statusCode) where statusCode == 410:
            return .expired(message: nil)
        case .noConnection, .timeout: return .network
        case .unauthorized, .server, .decoding, .unknown: return .unknown
        }
    }
}
