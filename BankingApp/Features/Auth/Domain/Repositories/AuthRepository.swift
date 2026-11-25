import Foundation

/// Hợp đồng của tầng Data. Domain chỉ biết protocol này.
protocol AuthRepository {
    func login(username: String, password: String) async throws -> AuthSession
    /// Làm mới phiên từ refresh token đã lưu (dùng sau khi xác thực sinh trắc học).
    func restoreSession() async throws -> AuthSession
    func hasStoredSession() -> Bool
    /// Người dùng của phiên đang lưu trên máy (nếu có).
    func storedUser() -> User?
    func logout() async
    /// Lưu phiên có sẵn (vd. vừa đăng ký xong, server trả token) để vào app luôn.
    func saveSession(_ session: AuthSession) throws

    func rememberedUsername() -> String?
    func setRememberedUsername(_ username: String?)

    func isBiometricLoginEnabled() -> Bool
    func setBiometricLoginEnabled(_ enabled: Bool)
}
