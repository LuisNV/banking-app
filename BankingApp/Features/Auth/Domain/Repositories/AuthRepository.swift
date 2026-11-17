import Foundation

/// Hợp đồng của tầng Data. Domain chỉ biết protocol này.
protocol AuthRepository {
    func login(username: String, password: String) async throws -> AuthSession
    /// Làm mới phiên từ refresh token đã lưu (dùng sau khi xác thực sinh trắc học).
    func restoreSession() async throws -> AuthSession
    func hasStoredSession() -> Bool
    func logout() async

    func rememberedUsername() -> String?
    func setRememberedUsername(_ username: String?)
}
