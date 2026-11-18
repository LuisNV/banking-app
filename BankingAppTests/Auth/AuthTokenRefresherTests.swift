import XCTest
@testable import BankingApp

private final class CountingRepository: AuthRepository {
    var restoreResult: Result<AuthSession, Error> = .success(.stub())
    private(set) var restoreCalls = 0

    func restoreSession() async throws -> AuthSession {
        restoreCalls += 1
        try await Task.sleep(for: .milliseconds(50))
        return try restoreResult.get()
    }

    func login(username: String, password: String) async throws -> AuthSession { .stub() }
    func hasStoredSession() -> Bool { true }
    func logout() async {}
    func rememberedUsername() -> String? { nil }
    func setRememberedUsername(_ username: String?) {}
}

final class AuthTokenRefresherTests: XCTestCase {
    func test_concurrentRefreshes_callServerOnce() async {
        let repository = CountingRepository()
        let sut = AuthTokenRefresher(repository: repository)

        async let first = sut.refreshTokens()
        async let second = sut.refreshTokens()
        let results = await [first, second]

        XCTAssertEqual(results, [true, true])
        XCTAssertEqual(repository.restoreCalls, 1)
    }

    func test_refreshFailure_returnsFalse() async {
        let repository = CountingRepository()
        repository.restoreResult = .failure(AuthError.sessionExpired)
        let sut = AuthTokenRefresher(repository: repository)

        let result = await sut.refreshTokens()

        XCTAssertFalse(result)
    }
}
