import XCTest
@testable import BankingApp

private final class MockRegisterUseCase: RegisterUseCaseProtocol {
    var createResult: Result<Void, Error> = .success(())
    var verifyResult: Result<Void, Error> = .success(())
    private(set) var createCalls = 0
    private(set) var verifiedCodes: [String] = []
    private(set) var resendCalls = 0

    func createAccount(info: RegistrationInfo, password: String) async throws {
        createCalls += 1
        try createResult.get()
    }

    func verifyEmail(email: String, code: String) async throws {
        verifiedCodes.append(code)
        try verifyResult.get()
    }

    func resendCode(email: String) async throws {
        resendCalls += 1
    }
}

@MainActor
final class RegisterViewModelTests: XCTestCase {
    private var useCase: MockRegisterUseCase!
    private var cancelled = false
    private var finishedEmail: String?

    override func setUp() {
        super.setUp()
        useCase = MockRegisterUseCase()
        cancelled = false
        finishedEmail = nil
    }

    private func makeSUT() -> RegisterViewModel {
        RegisterViewModel(
            registerUseCase: useCase,
            // Đếm ngược dừng ngay ở 45 giây để test ổn định.
            sleep: { _ in throw CancellationError() },
            onCancel: { [weak self] in self?.cancelled = true },
            onFinished: { [weak self] in self?.finishedEmail = $0 }
        )
    }

    private func fillValidInfo(_ sut: RegisterViewModel) {
        sut.fullName = "Nguyễn Minh Anh"
        sut.email = "MinhAnh@email.com"
        sut.phone = "0912345678"
    }

    func test_info_invalid_staysAndShowsErrorPopup() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isShowingError)
        XCTAssertEqual(sut.status(for: .email), .none)

        sut.continueFromInfo()

        XCTAssertEqual(sut.step, .info)
        XCTAssertTrue(sut.isShowingError)
        XCTAssertEqual(sut.errorTitle, RegisterViewModel.invalidInfoTitle)
        XCTAssertEqual(sut.errorMessage, RegisterViewModel.invalidInfoMessage)
        XCTAssertEqual(sut.infoErrorMessages.count, 3)
        XCTAssertEqual(sut.status(for: .email), .invalid)
    }

    func test_info_partiallyInvalid_showsGenericError() {
        let sut = makeSUT()
        sut.fullName = "Nguyễn Minh Anh"
        sut.email = "minhanh@email.com"
        sut.phone = "091234567"

        sut.continueFromInfo()

        XCTAssertEqual(sut.errorMessage, RegisterViewModel.invalidInfoMessage)
    }

    func test_info_validFieldShowsTick_beforeSubmit() {
        let sut = makeSUT()
        sut.email = "minhanh@email.com"
        XCTAssertEqual(sut.status(for: .email), .valid)
        sut.phone = "0912"
        XCTAssertEqual(sut.status(for: .phone), .none)
    }

    func test_info_valid_goesToPassword() {
        let sut = makeSUT()
        fillValidInfo(sut)
        sut.continueFromInfo()
        XCTAssertEqual(sut.step, .password)
        XCTAssertFalse(sut.isNavigatingBack)
    }

    func test_password_requiresRulesAndMatch() {
        let sut = makeSUT()
        sut.password = "Tingting1"
        sut.confirmPassword = "Tingting2"
        XCTAssertEqual(sut.confirmStatus, .invalid)
        XCTAssertFalse(sut.canCreateAccount)

        sut.confirmPassword = "Tingting1"
        XCTAssertEqual(sut.confirmStatus, .valid)
        XCTAssertTrue(sut.canCreateAccount)
    }

    func test_createAccount_success_goesToVerify_andStartsCountdown() async {
        let sut = makeSUT()
        fillValidInfo(sut)
        sut.continueFromInfo()
        sut.password = "Tingting1"
        sut.confirmPassword = "Tingting1"

        await sut.createAccount()

        XCTAssertEqual(useCase.createCalls, 1)
        XCTAssertEqual(sut.step, .verify)
        XCTAssertEqual(sut.resendSecondsLeft, RegisterViewModel.resendCooldown)
        XCTAssertFalse(sut.canResend)
        XCTAssertEqual(sut.resendTitle, "Gửi lại sau 0:45")
    }

    func test_createAccount_failure_showsError() async {
        useCase.createResult = .failure(RegisterError.emailTaken)
        let sut = makeSUT()
        sut.password = "Tingting1"
        sut.confirmPassword = "Tingting1"

        await sut.createAccount()

        XCTAssertEqual(sut.step, .info)
        XCTAssertEqual(sut.errorTitle, RegisterViewModel.defaultErrorTitle)
        XCTAssertEqual(sut.errorMessage, RegisterError.emailTaken.errorDescription)
    }

    func test_updateCode_keepsOnlySixDigits() {
        let sut = makeSUT()
        sut.updateCode("12a 34-5678")
        XCTAssertEqual(sut.code, "123456")
        XCTAssertTrue(sut.canVerify)
    }

    func test_verify_success_goesToDone_andFinishPassesEmail() async {
        let sut = makeSUT()
        fillValidInfo(sut)
        sut.updateCode("123456")

        await sut.verify()

        XCTAssertEqual(sut.step, .done)
        sut.finish()
        XCTAssertEqual(finishedEmail, "minhanh@email.com")
    }

    func test_verify_wrongCode_clearsCode_andShowsError() async {
        useCase.verifyResult = .failure(RegisterError.invalidCode)
        let sut = makeSUT()
        sut.updateCode("000000")

        await sut.verify()

        XCTAssertEqual(sut.code, "")
        XCTAssertEqual(sut.errorMessage, RegisterError.invalidCode.errorDescription)
        XCTAssertNotEqual(sut.step, .done)
    }

    func test_goBack_fromInfo_cancelsFlow() {
        let sut = makeSUT()
        sut.goBack()
        XCTAssertTrue(cancelled)
    }

    func test_goBack_fromPassword_returnsToInfo() {
        let sut = makeSUT()
        fillValidInfo(sut)
        sut.continueFromInfo()

        sut.goBack()

        XCTAssertEqual(sut.step, .info)
        XCTAssertTrue(sut.isNavigatingBack)
    }

    func test_stepNumbers() {
        XCTAssertEqual(RegisterViewModel.Step.info.number, 1)
        XCTAssertEqual(RegisterViewModel.Step.verify.number, 3)
        XCTAssertNil(RegisterViewModel.Step.done.number)
    }
}
