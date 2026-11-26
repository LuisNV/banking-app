import Foundation

/// `{API_BASE_URL}/v1/auth/password-resets`, không cần token.
protocol PasswordResetRepository {
    func start(identifier: String) async throws -> PasswordResetRequest
    func resendCode(resetId: String) async throws -> PasswordResetRequest?
    func verify(resetId: String, code: String) async throws -> PasswordResetVerification
    func complete(resetId: String, token: String, newPassword: String, confirmPassword: String)
        async throws -> PasswordResetResult
}
