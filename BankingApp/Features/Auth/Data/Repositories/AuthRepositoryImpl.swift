import Foundation

final class AuthRepositoryImpl: AuthRepository {
    private let remote: AuthRemoteDataSource
    private let local: AuthLocalDataSource
    private let device: DeviceInfoProviding

    init(remote: AuthRemoteDataSource, local: AuthLocalDataSource, device: DeviceInfoProviding) {
        self.remote = remote
        self.local = local
        self.device = device
    }

    func login(username: String, password: String) async throws -> AuthSession {
        do {
            let info = device.current
            let request = LoginRequestDTO(
                identifier: username,
                password: password,
                deviceId: info.id,
                deviceName: info.name,
                platform: info.platform
            )
            let dto = try await remote.login(request)
            let session = dto.toDomain()
            try local.saveTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
            local.saveUser(session.user)
            return session
        } catch {
            throw Self.map(error, unauthorized: .invalidCredentials)
        }
    }

    func restoreSession() async throws -> AuthSession {
        guard let refreshToken = local.refreshToken else { throw AuthError.biometricNotEnrolled }
        do {
            let dto = try await remote.refresh(RefreshTokenRequestDTO(refreshToken: refreshToken))
            var session = dto.toDomain()
            try local.saveTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
            if let user = session.user {
                local.saveUser(user)
            } else if let saved = local.savedUser {
                // Refresh không trả `user`: dùng thông tin đã lưu lúc đăng nhập.
                session = AuthSession(
                    user: saved,
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken,
                    expiresAt: session.expiresAt
                )
            }
            return session
        } catch {
            let mapped = Self.map(error, unauthorized: .sessionExpired)
            if mapped == .sessionExpired {
                local.clearTokens()
                local.saveUser(nil)
            }
            throw mapped
        }
    }

    func saveSession(_ session: AuthSession) throws {
        try local.saveTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
        local.saveUser(session.user)
    }

    func hasStoredSession() -> Bool {
        local.refreshToken != nil
    }

    func storedUser() -> User? {
        local.savedUser
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
        local.saveUser(nil)
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
