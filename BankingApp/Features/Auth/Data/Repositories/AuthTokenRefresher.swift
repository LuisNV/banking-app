import Foundation

/// Làm mới token khi access token hết hạn (được `AuthInterceptor` gọi khi gặp 401).
///
/// Là `actor` để nhiều request cùng bị 401 chỉ gọi `v1/auth/refresh` **một lần**:
/// các request đến sau chờ chung kết quả của lần đang chạy.
///
/// Nếu phiên đã hết hạn thật (server từ chối refresh token, hoặc máy không còn token)
/// thì gọi `onSessionExpired` để app quay về màn đăng nhập.
/// Lỗi mạng tạm thời **không** tính là hết phiên, để người dùng không bị đăng xuất oan.
actor AuthTokenRefresher: TokenRefresher {
    private let repository: AuthRepository
    private let onSessionExpired: @Sendable () -> Void
    private var inFlight: Task<Bool, Never>?

    init(repository: AuthRepository, onSessionExpired: @escaping @Sendable () -> Void = {}) {
        self.repository = repository
        self.onSessionExpired = onSessionExpired
    }

    func refreshTokens() async -> Bool {
        if let inFlight {
            return await inFlight.value
        }
        let repository = repository
        let onSessionExpired = onSessionExpired
        let task = Task<Bool, Never> {
            do {
                // restoreSession lưu cặp token mới; nếu refresh token hết hạn thì tự xoá token.
                _ = try await repository.restoreSession()
                return true
            } catch AuthError.sessionExpired, AuthError.biometricNotEnrolled {
                // biometricNotEnrolled ở đây nghĩa là trên máy không còn refresh token.
                onSessionExpired()
                return false
            } catch {
                return false
            }
        }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }
}
