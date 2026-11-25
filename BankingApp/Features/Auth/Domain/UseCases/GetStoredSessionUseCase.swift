import Foundation

/// Phiên còn lưu trên máy khi mở app.
struct StoredSession: Equatable {
    let user: User?
}

protocol GetStoredSessionUseCaseProtocol {
    /// `nil` nếu chưa đăng nhập (hoặc đã đăng xuất / hết phiên).
    func execute() -> StoredSession?
}

/// Mở app là vào thẳng Trang chủ nếu còn refresh token, không cần gọi mạng.
/// Access token hết hạn thì `AuthInterceptor` tự refresh ở request đầu tiên;
/// nếu server từ chối, app phát `sessionExpired` và `AppRouter` đưa về màn đăng nhập.
struct GetStoredSessionUseCase: GetStoredSessionUseCaseProtocol {
    let repository: AuthRepository

    func execute() -> StoredSession? {
        guard repository.hasStoredSession() else { return nil }
        return StoredSession(user: repository.storedUser())
    }
}
