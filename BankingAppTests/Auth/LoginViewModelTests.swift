import XCTest
@testable import BankingApp

@MainActor
final class LoginViewModelTests: XCTestCase {
    private var loginUseCase: MockLoginUseCase!
    private var biometricUseCase: MockBiometricLoginUseCase!
    private var preferencesUseCase: MockGetLoginPreferencesUseCase!
    private var authenticatedSession: AuthSession?

    override func setUp() {
        super.setUp()
        loginUseCase = MockLoginUseCase()
        biometricUseCase = MockBiometricLoginUseCase()
        preferencesUseCase = MockGetLoginPreferencesUseCase()
        authenticatedSession = nil
    }

    private func makeSUT() -> LoginViewModel {
        LoginViewModel(
            loginUseCase: loginUseCase,
            biometricLoginUseCase: biometricUseCase,
            getPreferencesUseCase: preferencesUseCase,
            onAuthenticated: { [weak self] in self?.authenticatedSession = $0 }
        )
    }

    func test_onAppear_prefillsRememberedUsername() {
        preferencesUseCase.preferences = LoginPreferences(
            rememberedUsername: "demo", biometricType: .faceID, canUseBiometricLogin: true
        )
        let sut = makeSUT()
        sut.onAppear()
        XCTAssertEqual(sut.username, "demo")
        XCTAssertTrue(sut.showsBiometricButton)
    }

    func test_canSubmit_requiresBothFields() {
        let sut = makeSUT()
        XCTAssertFalse(sut.canSubmit)
        sut.username = "demo"
        XCTAssertFalse(sut.canSubmit)
        sut.password = "123456"
        XCTAssertTrue(sut.canSubmit)
    }

    func test_login_success_callsOnAuthenticated_andClearsPassword() async {
        let sut = makeSUT()
        sut.username = "demo"
        sut.password = "123456"
        sut.rememberMe = false

        await sut.login()

        XCTAssertEqual(authenticatedSession, .stub())
        XCTAssertEqual(sut.password, "")
        XCTAssertEqual(loginUseCase.receivedRemember, false)
        XCTAssertFalse(sut.isLoading)
    }

    func test_login_failure_showsError() async {
        loginUseCase.result = .failure(AuthError.invalidCredentials)
        let sut = makeSUT()
        sut.username = "demo"
        sut.password = "wrong!"

        await sut.login()

        XCTAssertNil(authenticatedSession)
        XCTAssertTrue(sut.isShowingError)
        XCTAssertEqual(sut.errorMessage, AuthError.invalidCredentials.errorDescription)
    }

    func test_biometricCancelled_doesNotShowError() async {
        biometricUseCase.result = .failure(AuthError.biometricFailed)
        let sut = makeSUT()

        await sut.loginWithBiometrics()

        XCTAssertFalse(sut.isShowingError)
        XCTAssertNil(authenticatedSession)
    }

    func test_toggleDrawer() {
        let sut = makeSUT()
        sut.toggleDrawer()
        XCTAssertTrue(sut.isDrawerOpen)
    }
}
