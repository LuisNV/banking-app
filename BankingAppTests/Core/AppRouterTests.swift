import XCTest
@testable import BankingApp

@MainActor
final class AppRouterTests: XCTestCase {
    func test_sessionExpired_onHome_showsLoginWithMessage() {
        let sut = AppRouter()
        sut.showHome(with: .stub())

        sut.handleSessionExpired()

        XCTAssertEqual(sut.route, .login)
        XCTAssertEqual(sut.sessionExpiredMessage, AuthError.sessionExpired.errorDescription)
        XCTAssertTrue(sut.isShowingSessionExpired)
    }

    func test_sessionExpired_onLogin_doesNothing() {
        let sut = AppRouter()

        sut.handleSessionExpired()

        XCTAssertEqual(sut.route, .login)
        XCTAssertNil(sut.sessionExpiredMessage)
    }

    func test_dismissAlert_clearsMessage() {
        let sut = AppRouter()
        sut.showHome(with: .stub())
        sut.handleSessionExpired()

        sut.isShowingSessionExpired = false

        XCTAssertNil(sut.sessionExpiredMessage)
    }

    func test_register_thenFinish_showsLoginWithPrefilledEmail() {
        let sut = AppRouter()

        sut.showRegister()
        XCTAssertEqual(sut.route, .register)

        sut.showLogin(prefilledUsername: "minhanh@email.com")
        XCTAssertEqual(sut.route, .login)
        XCTAssertEqual(sut.prefilledUsername, "minhanh@email.com")

        sut.showHome(with: .stub())
        XCTAssertNil(sut.prefilledUsername)
    }
}
