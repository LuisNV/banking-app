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
    func isBiometricLoginEnabled() -> Bool { true }
    func setBiometricLoginEnabled(_ enabled: Bool) {}
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

    func test_sessionExpired_notifiesOnce() async {
        let repository = CountingRepository()
        repository.restoreResult = .failure(AuthError.sessionExpired)
        let counter = Counter()
        let sut = AuthTokenRefresher(repository: repository) { counter.increment() }

        async let first = sut.refreshTokens()
        async let second = sut.refreshTokens()
        _ = await [first, second]

        XCTAssertEqual(counter.value, 1)
    }

    func test_missingRefreshToken_notifiesSessionExpired() async {
        let repository = CountingRepository()
        repository.restoreResult = .failure(AuthError.biometricNotEnrolled)
        let counter = Counter()
        let sut = AuthTokenRefresher(repository: repository) { counter.increment() }

        _ = await sut.refreshTokens()

        XCTAssertEqual(counter.value, 1)
    }

    func test_networkError_doesNotNotifySessionExpired() async {
        let repository = CountingRepository()
        repository.restoreResult = .failure(AuthError.network)
        let counter = Counter()
        let sut = AuthTokenRefresher(repository: repository) { counter.increment() }

        let result = await sut.refreshTokens()

        XCTAssertFalse(result)
        XCTAssertEqual(counter.value, 0)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
