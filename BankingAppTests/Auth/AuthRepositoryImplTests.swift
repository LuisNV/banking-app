import XCTest
@testable import BankingApp

private final class StubRemote: AuthRemoteDataSource {
    var loginError: Error?
    var refreshError: Error?

    let response = AuthResponseDTO(
        accessToken: "a", refreshToken: "r", expiresIn: 60,
        user: UserDTO(id: "1", fullName: "Demo", username: "demo")
    )

    func login(_ request: LoginRequestDTO) async throws -> AuthResponseDTO {
        if let loginError { throw loginError }
        return response
    }

    func refresh(_ request: RefreshTokenRequestDTO) async throws -> AuthResponseDTO {
        if let refreshError { throw refreshError }
        return response
    }

    func logout() async throws {}
}

private final class InMemoryLocal: AuthLocalDataSource {
    var refreshToken: String?
    var accessToken: String?
    var rememberedUsername: String?

    func saveTokens(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }

    func setRememberedUsername(_ username: String?) { rememberedUsername = username }
}

final class AuthRepositoryImplTests: XCTestCase {
    func test_login_savesTokens() async throws {
        let local = InMemoryLocal()
        let sut = AuthRepositoryImpl(remote: StubRemote(), local: local)

        let session = try await sut.login(username: "demo", password: "123456")

        XCTAssertEqual(session.user.username, "demo")
        XCTAssertEqual(local.refreshToken, "r")
        XCTAssertTrue(sut.hasStoredSession())
    }

    func test_login_unauthorized_mapsToInvalidCredentials() async {
        let remote = StubRemote()
        remote.loginError = NetworkError.unauthorized
        let sut = AuthRepositoryImpl(remote: remote, local: InMemoryLocal())
        do {
            _ = try await sut.login(username: "demo", password: "x")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    func test_restore_unauthorized_clearsTokens() async {
        let remote = StubRemote()
        remote.refreshError = NetworkError.unauthorized
        let local = InMemoryLocal()
        local.refreshToken = "old"
        let sut = AuthRepositoryImpl(remote: remote, local: local)
        do {
            _ = try await sut.restoreSession()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionExpired)
        }
        XCTAssertNil(local.refreshToken)
    }
}
