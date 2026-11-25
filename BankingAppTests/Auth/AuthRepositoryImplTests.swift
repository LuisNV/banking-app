import XCTest
@testable import BankingApp

private final class StubRemote: AuthRemoteDataSource {
    var loginError: Error?
    var refreshError: Error?
    var logoutError: Error?
    private(set) var refreshRequests: [String] = []
    private(set) var loginRequests: [LoginRequestDTO] = []
    private(set) var logoutRequests: [String] = []

    var response = AuthResponseDTO(
        accessToken: "a", refreshToken: "r", expiresIn: 60, tokenType: "Bearer",
        user: UserDTO(id: "1", fullName: "Demo", username: "demo")
    )

    func login(_ request: LoginRequestDTO) async throws -> AuthResponseDTO {
        loginRequests.append(request)
        if let loginError { throw loginError }
        return response
    }

    func refresh(_ request: RefreshTokenRequestDTO) async throws -> AuthResponseDTO {
        refreshRequests.append(request.refreshToken)
        if let refreshError { throw refreshError }
        return response
    }

    func logout(_ request: LogoutRequestDTO) async throws {
        logoutRequests.append(request.refreshToken)
        if let logoutError { throw logoutError }
    }
}

private struct StubDevice: DeviceInfoProviding {
    var current: DeviceInfo {
        DeviceInfo(id: "3f2b8c1e-9a4d-4e7b-b1c2-5d6e7f809a1b", name: "iPhone 15 Pro", platform: "iOS 18.1")
    }
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

    var savedUser: User?
    func saveUser(_ user: User?) { savedUser = user }

    var isBiometricLoginEnabled = true
    func setBiometricLoginEnabled(_ enabled: Bool) { isBiometricLoginEnabled = enabled }
}

final class AuthRepositoryImplTests: XCTestCase {
    func test_login_savesTokens() async throws {
        let local = InMemoryLocal()
        let sut = AuthRepositoryImpl(remote: StubRemote(), local: local, device: StubDevice())

        let session = try await sut.login(username: "demo", password: "123456")

        XCTAssertEqual(session.user?.username, "demo")
        XCTAssertEqual(local.refreshToken, "r")
        XCTAssertTrue(sut.hasStoredSession())
    }

    func test_login_savesUser_andLogoutClearsIt() async throws {
        let local = InMemoryLocal()
        let sut = AuthRepositoryImpl(remote: StubRemote(), local: local, device: StubDevice())

        _ = try await sut.login(username: "demo", password: "123456")
        XCTAssertEqual(sut.storedUser(), User(id: "1", fullName: "Demo", username: "demo"))

        await sut.logout()
        XCTAssertNil(sut.storedUser())
    }

    func test_restore_withoutUserInResponse_usesSavedUser() async throws {
        let remote = StubRemote()
        remote.response = AuthResponseDTO(accessToken: "a", refreshToken: "r", expiresIn: 60, tokenType: "Bearer", user: nil)
        let local = InMemoryLocal()
        local.refreshToken = "old"
        local.savedUser = User(id: "9", fullName: "Nguyễn Minh Anh", username: "minhanh@email.com")
        let sut = AuthRepositoryImpl(remote: remote, local: local, device: StubDevice())

        let session = try await sut.restoreSession()

        XCTAssertEqual(session.user?.fullName, "Nguyễn Minh Anh")
    }

    func test_restore_unauthorized_clearsSavedUser() async {
        let remote = StubRemote()
        remote.refreshError = NetworkError.unauthorized
        let local = InMemoryLocal()
        local.refreshToken = "old"
        local.savedUser = User(id: "9", fullName: "A", username: "a")
        let sut = AuthRepositoryImpl(remote: remote, local: local, device: StubDevice())

        _ = try? await sut.restoreSession()

        XCTAssertNil(local.savedUser)
    }

    /// Khớp curl: {"email", "password", "deviceId", "deviceName", "platform"}.
    func test_login_sendsDeviceInfo() async throws {
        let remote = StubRemote()
        let sut = AuthRepositoryImpl(remote: remote, local: InMemoryLocal(), device: StubDevice())

        _ = try await sut.login(username: "user@example.com", password: "Matkhau123")

        let request = try XCTUnwrap(remote.loginRequests.first)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: String]
        XCTAssertEqual(json, [
            "email": "user@example.com",
            "password": "Matkhau123",
            "deviceId": "3f2b8c1e-9a4d-4e7b-b1c2-5d6e7f809a1b",
            "deviceName": "iPhone 15 Pro",
            "platform": "iOS 18.1",
        ])
    }

    func test_deviceMarketingName() {
        XCTAssertEqual(SystemDeviceInfoProvider.marketingName(for: "iPhone16,1"), "iPhone 15 Pro")
        XCTAssertEqual(SystemDeviceInfoProvider.marketingName(for: "iPhone99,9"), "iPhone (iPhone99,9)")
    }

    func test_login_unauthorized_mapsToInvalidCredentials() async {
        let remote = StubRemote()
        remote.loginError = NetworkError.unauthorized
        let sut = AuthRepositoryImpl(remote: remote, local: InMemoryLocal(), device: StubDevice())
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
        let sut = AuthRepositoryImpl(remote: remote, local: local, device: StubDevice())
        do {
            _ = try await sut.restoreSession()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionExpired)
        }
        XCTAssertNil(local.refreshToken)
    }

    func test_restore_sendsStoredRefreshToken_andSavesNewTokens() async throws {
        let remote = StubRemote()
        let local = InMemoryLocal()
        local.refreshToken = "old"
        let sut = AuthRepositoryImpl(remote: remote, local: local, device: StubDevice())

        _ = try await sut.restoreSession()

        XCTAssertEqual(remote.refreshRequests, ["old"])
        XCTAssertEqual(local.accessToken, "a")
        XCTAssertEqual(local.refreshToken, "r")
    }

    func test_logout_sendsRefreshToken_andClearsTokens() async {
        let remote = StubRemote()
        let local = InMemoryLocal()
        local.accessToken = "access"
        local.refreshToken = "refresh"
        let sut = AuthRepositoryImpl(remote: remote, local: local, device: StubDevice())

        await sut.logout()

        XCTAssertEqual(remote.logoutRequests, ["refresh"])
        XCTAssertNil(local.accessToken)
        XCTAssertNil(local.refreshToken)
        XCTAssertFalse(sut.hasStoredSession())
    }

    func test_logout_networkError_stillClearsTokens() async {
        let remote = StubRemote()
        remote.logoutError = NetworkError.noConnection
        let local = InMemoryLocal()
        local.refreshToken = "refresh"
        let sut = AuthRepositoryImpl(remote: remote, local: local, device: StubDevice())

        await sut.logout()

        XCTAssertNil(local.refreshToken)
    }

    func test_logout_withoutStoredToken_skipsRemoteCall() async {
        let remote = StubRemote()
        let sut = AuthRepositoryImpl(remote: remote, local: InMemoryLocal(), device: StubDevice())

        await sut.logout()

        XCTAssertTrue(remote.logoutRequests.isEmpty)
    }

    func test_logoutRequest_encodesCamelCaseRefreshToken() throws {
        let data = try JSONEncoder().encode(LogoutRequestDTO(refreshToken: "x"))
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"refreshToken":"x"}"#)
    }
}

final class AuthEndpointTests: XCTestCase {
    /// Khớp với: POST {API_BASE_URL}/v1/auth/logout, body {"refreshToken": "..."}, không cần Bearer.
    func test_logoutEndpoint_matchesBackendContract() throws {
        let endpoint = AuthEndpoint.logout(LogoutRequestDTO(refreshToken: "rt-123"))

        XCTAssertEqual(endpoint.path, "v1/auth/logout")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertFalse(endpoint.requiresAuth)
        XCTAssertEqual(endpoint.timeout, 10)

        let body = try XCTUnwrap(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AnyEncodable(body))) as? [String: String]
        XCTAssertEqual(json, ["refreshToken": "rt-123"])
    }
}
