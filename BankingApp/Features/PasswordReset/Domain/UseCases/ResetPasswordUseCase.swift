import Foundation

protocol ResetPasswordUseCaseProtocol {
    func start(identifier: String) async throws -> PasswordResetRequest
    func resendCode(resetId: String) async throws -> PasswordResetRequest?
    func verify(resetId: String, code: String) async throws -> PasswordResetVerification
    /// Đặt mật khẩu mới. Thành công thì xoá phiên đăng nhập trên máy (server đã đăng xuất mọi thiết bị).
    func complete(resetId: String, token: String, newPassword: String, confirmPassword: String)
        async throws -> PasswordResetResult
}

struct ResetPasswordUseCase: ResetPasswordUseCaseProtocol {
    static let codeLength = 6

    let repository: PasswordResetRepository
    let authRepository: AuthRepository

    func start(identifier: String) async throws -> PasswordResetRequest {
        guard PasswordResetValidator.isValidIdentifier(identifier) else {
            throw PasswordResetError.invalidIdentifier(message: nil)
        }
        return try await repository.start(identifier: LoginUseCase.normalizedIdentifier(identifier))
    }

    func resendCode(resetId: String) async throws -> PasswordResetRequest? {
        try await repository.resendCode(resetId: resetId)
    }

    func verify(resetId: String, code: String) async throws -> PasswordResetVerification {
        guard code.count == Self.codeLength, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw PasswordResetError.invalidCode(message: nil)
        }
        return try await repository.verify(resetId: resetId, code: code)
    }

    func complete(resetId: String, token: String, newPassword: String, confirmPassword: String)
        async throws -> PasswordResetResult {
        let errors = PasswordResetValidator.errors(new: newPassword, confirm: confirmPassword)
        guard errors.isEmpty else { throw PasswordResetError.invalidPassword(errors) }
        let result = try await repository.complete(
            resetId: resetId, token: token, newPassword: newPassword, confirmPassword: confirmPassword
        )
        // Token cũ đã bị thu hồi; xoá trên máy để không còn đăng nhập bằng Face ID với phiên cũ.
        authRepository.discardSession()
        return result
    }
}
