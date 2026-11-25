import XCTest
@testable import BankingApp

private struct StubStoredSession: GetStoredSessionUseCaseProtocol {
    let session: StoredSession?
    func execute() -> StoredSession? { session }
}

@MainActor
final class AppRouterTests: XCTestCase {
    private func makeSUT(storedSession: StoredSession? = nil) -> AppRouter {
        AppRouter(storedSession: StubStoredSession(session: storedSession))
    }

    func test_launch_withStoredSession_opensHome() {
        let user = User(id: "1", fullName: "Nguyễn Minh Anh", username: "minhanh@email.com")
        let sut = makeSUT(storedSession: StoredSession(user: user))

        XCTAssertEqual(sut.route, .home(user))
    }

    func test_launch_withoutStoredSession_opensLogin() {
        XCTAssertEqual(makeSUT().route, .login)
    }

    func test_launch_withStoredSession_thenExpired_returnsToLogin() {
        let sut = makeSUT(storedSession: StoredSession(user: nil))

        sut.handleSessionExpired()

        XCTAssertEqual(sut.route, .login)
        XCTAssertTrue(sut.isShowingSessionExpired)
    }

    func test_sessionExpired_onHome_showsLoginWithMessage() {
        let sut = makeSUT()
        sut.showHome(with: .stub())

        sut.handleSessionExpired()

        XCTAssertEqual(sut.route, .login)
        XCTAssertEqual(sut.sessionExpiredMessage, AuthError.sessionExpired.errorDescription)
        XCTAssertTrue(sut.isShowingSessionExpired)
    }

    func test_sessionExpired_onLogin_doesNothing() {
        let sut = makeSUT()

        sut.handleSessionExpired()

        XCTAssertEqual(sut.route, .login)
        XCTAssertNil(sut.sessionExpiredMessage)
    }

    func test_dismissAlert_clearsMessage() {
        let sut = makeSUT()
        sut.showHome(with: .stub())
        sut.handleSessionExpired()

        sut.isShowingSessionExpired = false

        XCTAssertNil(sut.sessionExpiredMessage)
    }

    func test_register_thenFinish_showsLoginWithPrefilledEmail() {
        let sut = makeSUT()

        sut.showRegister()
        XCTAssertEqual(sut.route, .register)

        sut.showLogin(prefilledUsername: "minhanh@email.com")
        XCTAssertEqual(sut.route, .login)
        XCTAssertEqual(sut.prefilledUsername, "minhanh@email.com")

        sut.showHome(with: .stub())
        XCTAssertNil(sut.prefilledUsername)
    }
}
