import Foundation

/// `{API_BASE_URL}/v1/auth/password-changes`, cần access token.
protocol PasswordChangeRepository {
    /// Bước 1: kiểm tra mật khẩu, tạo yêu cầu và gửi mã tới email.
    func start(currentPassword: String, newPassword: String, confirmPassword: String, logoutOtherDevices: Bool)
        async throws -> PasswordChangeRequest
    func resendCode(requestId: String) async throws -> PasswordChangeRequest?
    /// Bước 2: nhập mã để áp dụng mật khẩu mới.
    func verify(requestId: String, code: String) async throws -> PasswordChangeResult
}
