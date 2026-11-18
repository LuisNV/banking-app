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
}
