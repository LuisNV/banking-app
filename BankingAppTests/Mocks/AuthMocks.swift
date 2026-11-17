import Foundation
@testable import BankingApp

extension AuthSession {
    static func stub(username: String = "demo") -> AuthSession {
        AuthSession(
            user: User(id: "1", fullName: "Demo", username: username),
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(900)
        )
    }
}

final class MockAuthRepository: AuthRepository {
    var loginResult: Result<AuthSession, Error> = .success(.stub())
    var restoreResult: Result<AuthSession, Error> = .success(.stub())
    var storedSession = true
    var savedUsername: String?
    private(set) var loginCalls: [(String, String)] = []
    private(set) var logoutCalled = false

    func login(username: String, password: String) async throws -> AuthSession {
        loginCalls.append((username, password))
        return try loginResult.get()
    }

    func restoreSession() async throws -> AuthSession { try restoreResult.get() }
    func hasStoredSession() -> Bool { storedSession }
    func logout() async { logoutCalled = true }
    func rememberedUsername() -> String? { savedUsername }
    func setRememberedUsername(_ username: String?) { savedUsername = username }
}

final class MockBiometricAuthService: BiometricAuthService {
    var availableType: BiometricType = .faceID
    var authenticateResult: Result<Bool, Error> = .success(true)

    func authenticate(reason: String) async throws -> Bool {
        try authenticateResult.get()
    }
}

final class MockLoginUseCase: LoginUseCaseProtocol {
    var result: Result<AuthSession, Error> = .success(.stub())
    private(set) var receivedRemember: Bool?

    func execute(username: String, password: String, rememberUsername: Bool) async throws -> AuthSession {
        receivedRemember = rememberUsername
        return try result.get()
    }
}

final class MockBiometricLoginUseCase: BiometricLoginUseCaseProtocol {
    var result: Result<AuthSession, Error> = .success(.stub())
    func execute() async throws -> AuthSession { try result.get() }
}

final class MockGetLoginPreferencesUseCase: GetLoginPreferencesUseCaseProtocol {
    var preferences = LoginPreferences(rememberedUsername: nil, biometricType: .faceID, canUseBiometricLogin: true)
    func execute() -> LoginPreferences { preferences }
}
