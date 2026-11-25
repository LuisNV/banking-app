import Foundation

final class AuthRepositoryImpl: AuthRepository {
    private let remote: AuthRemoteDataSource
    private let local: AuthLocalDataSource

    init(remote: AuthRemoteDataSource, local: AuthLocalDataSource) {
        self.remote = remote
        self.local = local
    }

    func login(username: String, password: String) async throws -> AuthSession {
        do {
            let dto = try await remote.login(LoginRequestDTO(email: username, password: password))
            let session = dto.toDomain()
            try local.saveTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
            return session
        } catch {
            throw Self.map(error, unauthorized: .invalidCredentials)
        }
    }

    func restoreSession() async throws -> AuthSession {
        guard let refreshToken = local.refreshToken else { throw AuthError.biometricNotEnrolled }
        do {
            let dto = try await remote.refresh(RefreshTokenRequestDTO(refreshToken: refreshToken))
            let session = dto.toDomain()
            try local.saveTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
            return session
        } catch {
            let mapped = Self.map(error, unauthorized: .sessionExpired)
            if mapped == .sessionExpired { local.clearTokens() }
            throw mapped
        }
    }

    func hasStoredSession() -> Bool {
        local.refreshToken != nil
    }

    /// Gửi refresh token để server thu hồi, rồi xoá token trên máy.
    /// Token luôn bị xoá kể cả khi gọi API lỗi (mất mạng...), để đăng xuất không bao giờ bị kẹt.
    /// Vì refresh token đã bị thu hồi, lần sau phải đăng nhập bằng mật khẩu
    /// trước khi dùng lại được sinh trắc học.
    func logout() async {
        if let refreshToken = local.refreshToken {
            try? await remote.logout(LogoutRequestDTO(refreshToken: refreshToken))
        }
        local.clearTokens()
    }

    func rememberedUsername() -> String? {
        local.rememberedUsername
    }

    func setRememberedUsername(_ username: String?) {
        local.setRememberedUsername(username)
    }

    func isBiometricLoginEnabled() -> Bool {
        local.isBiometricLoginEnabled
    }

    func setBiometricLoginEnabled(_ enabled: Bool) {
        local.setBiometricLoginEnabled(enabled)
    }

    private static func map(_ error: Error, unauthorized: AuthError) -> AuthError {
        if let authError = error as? AuthError { return authError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        case .unauthorized: return unauthorized
        case .api(_, let httpStatus, let message, _):
            if httpStatus == 401 && unauthorized == .sessionExpired {
                return .sessionExpired
            }
            return message.isEmpty ? .unknown : .api(message: message)
        case .noConnection, .timeout: return .network
        case .server, .decoding, .unknown: return .unknown
        }
    }
}
