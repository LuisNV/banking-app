import Foundation

/// Làm mới token khi access token hết hạn (được `AuthInterceptor` gọi khi gặp 401).
///
/// Là `actor` để nhiều request cùng bị 401 chỉ gọi `v1/auth/refresh` **một lần**:
/// các request đến sau chờ chung kết quả của lần đang chạy.
actor AuthTokenRefresher: TokenRefresher {
    private let repository: AuthRepository
    private var inFlight: Task<Bool, Never>?

    init(repository: AuthRepository) {
        self.repository = repository
    }

    func refreshTokens() async -> Bool {
        if let inFlight {
            return await inFlight.value
        }
        let repository = repository
        let task = Task<Bool, Never> {
            // restoreSession lưu cặp token mới; nếu refresh token hết hạn thì tự xoá token.
            (try? await repository.restoreSession()) != nil
        }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }
}
