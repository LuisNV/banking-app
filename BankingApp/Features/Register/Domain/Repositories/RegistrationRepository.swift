import Foundation

/// Các API đăng ký: `{API_BASE_URL}/v1/auth/registrations`, không cần token.
protocol RegistrationRepository {
    /// Bước 1: tạo phiên (chưa tạo user).
    func start(_ info: RegistrationInfo) async throws -> RegistrationSession
    /// Bước 2: đặt mật khẩu; lần đầu server gửi mã tới email.
    func initiate(id: String, password: String, confirmPassword: String, biometricEnabled: Bool) async throws -> RegistrationSession
    /// Bước 3: xác minh mã 6 số.
    func verify(id: String, code: String) async throws -> RegistrationSession
    func resendCode(id: String) async throws -> RegistrationSession
    /// Đổi email nhận mã; mã mới được gửi ngay.
    func changeEmail(id: String, email: String) async throws -> RegistrationSession
    /// Bước 4: tạo user và đăng nhập luôn.
    func complete(id: String) async throws -> RegistrationResult
    /// Trạng thái phiên (mở lại app giữa chừng).
    func status(id: String) async throws -> RegistrationSession

    // MARK: Lưu trên máy
    func savedRegistration() -> SavedRegistration?
    func saveRegistration(_ registration: SavedRegistration?)
}
