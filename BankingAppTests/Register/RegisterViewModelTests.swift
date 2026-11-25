import XCTest
@testable import BankingApp

private final class MockRegisterUseCase: RegisterUseCaseProtocol {
    var startResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .setPassword))
    var setPasswordResult: Result<RegistrationSession, Error> = .success(RegistrationSession(
        id: "reg-1", nextStep: .verifyEmail,
        otp: RegistrationOTP(expiresAt: nil, resendAvailableAt: nil, remainingAttempts: 5)
    ))
    var verifyResults: [Result<RegistrationSession, Error>] = []
    var resendResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .verifyEmail))
    var changeEmailResult: Result<RegistrationSession, Error> = .success(
        RegistrationSession(id: "reg-1", nextStep: .verifyEmail, email: "moi@gmail.com")
    )
    var completeResult: Result<AuthSession, Error> = .success(.stub(username: "minhanh@email.com"))
    var resumeResult: (saved: SavedRegistration, session: RegistrationSession)?

    private(set) var startCalls = 0
    private(set) var setPasswordCalls: [(password: String, biometric: Bool)] = []
    private(set) var verifiedCodes: [String] = []
    private(set) var completeCalls = 0
    private(set) var changedEmails: [String] = []
    private(set) var discardCalls = 0

    func start(info: RegistrationInfo) async throws -> RegistrationSession {
        startCalls += 1
        return try startResult.get()
    }

    func setPassword(id: String, password: String, confirmPassword: String, biometricEnabled: Bool) async throws -> RegistrationSession {
        setPasswordCalls.append((password, biometricEnabled))
        return try setPasswordResult.get()
    }

    func verify(id: String, code: String) async throws -> RegistrationSession {
        verifiedCodes.append(code)
        guard !verifyResults.isEmpty else { return RegistrationSession(id: id, nextStep: .complete) }
        return try verifyResults.removeFirst().get()
    }

    func resendCode(id: String) async throws -> RegistrationSession { try resendResult.get() }

    func changeEmail(id: String, email: String) async throws -> RegistrationSession {
        changedEmails.append(email)
        return try changeEmailResult.get()
    }

    func complete(id: String) async throws -> AuthSession {
        completeCalls += 1
        return try completeResult.get()
    }

    func resume() async -> (saved: SavedRegistration, session: RegistrationSession)? { resumeResult }
    func discard() { discardCalls += 1 }
}

@MainActor
final class RegisterViewModelTests: XCTestCase {
    private var useCase: MockRegisterUseCase!
    private var cancelled = false
    private var finishedSession: AuthSession?
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        useCase = MockRegisterUseCase()
        cancelled = false
        finishedSession = nil
    }

    private func makeSUT(biometricType: BiometricType = .faceID) -> RegisterViewModel {
        RegisterViewModel(
            registerUseCase: useCase,
            biometricType: biometricType,
            now: { [now] in now },
            // Đếm ngược dừng ngay để test ổn định.
            sleep: { _ in throw CancellationError() },
            onCancel: { [weak self] in self?.cancelled = true },
            onFinished: { [weak self] in self?.finishedSession = $0 }
        )
    }

    private func fillValidInfo(_ sut: RegisterViewModel) {
        sut.fullName = "Nguyễn Minh Anh"
        sut.email = "MinhAnh@email.com"
        sut.phone = "091 234 5678"
    }

    private func goToVerify(_ sut: RegisterViewModel) async {
        fillValidInfo(sut)
        await sut.continueFromInfo()
        sut.password = "Matkhau123"
        sut.confirmPassword = "Matkhau123"
        await sut.createAccount()
    }

    // MARK: Bước 1

    func test_info_invalid_staysAndShowsErrorPopup_withoutCallingServer() async {
        let sut = makeSUT()

        await sut.continueFromInfo()

        XCTAssertEqual(sut.step, .info)
        XCTAssertEqual(sut.errorTitle, RegisterViewModel.invalidInfoTitle)
        XCTAssertEqual(sut.errorMessage, RegisterViewModel.invalidInfoMessage)
        XCTAssertEqual(sut.status(for: .email), .invalid)
        XCTAssertEqual(useCase.startCalls, 0)
    }

    func test_info_valid_createsSession_andGoesToPassword() async {
        let sut = makeSUT()
        fillValidInfo(sut)

        await sut.continueFromInfo()

        XCTAssertEqual(useCase.startCalls, 1)
        XCTAssertEqual(sut.registrationId, "reg-1")
        XCTAssertEqual(sut.step, .password)
    }

    func test_info_unchanged_reusesSession_changed_createsNew() async {
        let sut = makeSUT()
        fillValidInfo(sut)
        await sut.continueFromInfo()
        sut.goBack()

        await sut.continueFromInfo()
        XCTAssertEqual(useCase.startCalls, 1)

        sut.goBack()
        sut.fullName = "Trần An"
        await sut.continueFromInfo()
        XCTAssertEqual(useCase.startCalls, 2)
    }

    func test_info_emailTaken_marksEmailField_untilEdited() async {
        useCase.startResult = .failure(RegisterError.emailTaken)
        let sut = makeSUT()
        fillValidInfo(sut)

        await sut.continueFromInfo()

        XCTAssertEqual(sut.step, .info)
        XCTAssertEqual(sut.status(for: .email), .invalid)
        XCTAssertEqual(sut.errorMessage, RegisterError.emailTaken.errorDescription)

        sut.didEdit(.email)
        XCTAssertEqual(sut.status(for: .email), .valid)
    }

    func test_info_phoneTaken_marksPhoneField() async {
        useCase.startResult = .failure(RegisterError.phoneTaken)
        let sut = makeSUT()
        fillValidInfo(sut)

        await sut.continueFromInfo()

        XCTAssertEqual(sut.status(for: .phone), .invalid)
    }

    // MARK: Bước 2

    func test_password_requiresRulesAndMatch() {
        let sut = makeSUT()
        sut.password = "Matkhau123"
        sut.confirmPassword = "Matkhau124"
        XCTAssertEqual(sut.confirmStatus, .invalid)
        XCTAssertFalse(sut.canCreateAccount)

        sut.confirmPassword = "Matkhau123"
        XCTAssertTrue(sut.canCreateAccount)
    }

    func test_biometric_defaultsOnWhenAvailable() {
        XCTAssertTrue(makeSUT(biometricType: .faceID).biometricEnabled)
        XCTAssertFalse(makeSUT(biometricType: .none).biometricEnabled)
    }

    func test_createAccount_sendsBiometric_goesToVerify_andStartsCountdown() async {
        let sut = makeSUT()
        await goToVerify(sut)

        XCTAssertEqual(useCase.setPasswordCalls.first?.biometric, true)
        XCTAssertEqual(sut.step, .verify)
        XCTAssertEqual(sut.resendSecondsLeft, RegisterViewModel.resendCooldown)
        XCTAssertEqual(sut.resendTitle, "Gửi lại sau 0:45")
    }

    func test_countdown_followsServerResendAvailableAt() async {
        useCase.setPasswordResult = .success(RegistrationSession(
            id: "reg-1", nextStep: .verifyEmail,
            otp: RegistrationOTP(expiresAt: nil, resendAvailableAt: now.addingTimeInterval(20), remainingAttempts: 5)
        ))
        let sut = makeSUT()
        await goToVerify(sut)

        XCTAssertEqual(sut.resendSecondsLeft, 20)
    }

    func test_sessionExpired_returnsToInfo_keepingInput() async {
        useCase.setPasswordResult = .failure(RegisterError.sessionExpired)
        let sut = makeSUT()
        await goToVerify(sut)

        XCTAssertEqual(sut.step, .info)
        XCTAssertNil(sut.registrationId)
        XCTAssertEqual(sut.fullName, "Nguyễn Minh Anh")
        XCTAssertEqual(sut.errorTitle, RegisterViewModel.restartTitle)
        XCTAssertGreaterThan(useCase.discardCalls, 0)
    }

    // MARK: Bước 3

    func test_updateCode_keepsOnlySixDigits() {
        let sut = makeSUT()
        sut.updateCode("12a 34-5678")
        XCTAssertEqual(sut.code, "123456")
        XCTAssertTrue(sut.canVerify)
    }

    func test_verify_success_completes_andFinishPassesSession() async {
        let sut = makeSUT()
        await goToVerify(sut)
        sut.updateCode("482719")

        await sut.verify()

        XCTAssertEqual(useCase.completeCalls, 1)
        XCTAssertEqual(sut.step, .done)
        sut.finish()
        XCTAssertEqual(finishedSession?.user?.username, "minhanh@email.com")
    }

    func test_verify_wrongCode_showsServerMessage_andClearsCode() async {
        useCase.verifyResults = [.failure(RegisterError.invalidCode(message: "Mã không đúng. Bạn còn 4 lần thử"))]
        let sut = makeSUT()
        await goToVerify(sut)
        sut.updateCode("000000")

        await sut.verify()

        XCTAssertEqual(sut.code, "")
        XCTAssertEqual(sut.errorMessage, "Mã không đúng. Bạn còn 4 lần thử")
        XCTAssertEqual(sut.step, .verify)
    }

    func test_changeEmail_updatesEmail_andRestartsCountdown() async {
        let sut = makeSUT()
        await goToVerify(sut)
        sut.showChangeEmail()
        XCTAssertTrue(sut.isShowingChangeEmail)
        XCTAssertFalse(sut.canSubmitNewEmail, "Email chưa đổi")

        sut.newEmail = " Moi@Gmail.com "
        await sut.submitNewEmail()

        XCTAssertEqual(useCase.changedEmails, ["moi@gmail.com"])
        XCTAssertEqual(sut.normalizedEmail, "moi@gmail.com")
        XCTAssertFalse(sut.isShowingChangeEmail)
        XCTAssertEqual(sut.resendSecondsLeft, RegisterViewModel.resendCooldown)
    }

    func test_changeEmail_taken_showsErrorInSheet() async {
        useCase.changeEmailResult = .failure(RegisterError.emailTaken)
        let sut = makeSUT()
        await goToVerify(sut)
        sut.showChangeEmail()
        sut.newEmail = "taken@example.com"

        await sut.submitNewEmail()

        XCTAssertTrue(sut.isShowingChangeEmail)
        XCTAssertEqual(sut.changeEmailError, RegisterError.emailTaken.errorDescription)
    }

    // MARK: Điều hướng & mở lại

    func test_goBack_fromInfo_cancelsAndDiscards() {
        let sut = makeSUT()
        sut.goBack()
        XCTAssertTrue(cancelled)
        XCTAssertEqual(useCase.discardCalls, 1)
    }

    func test_goBack_fromVerify_returnsToPassword() async {
        let sut = makeSUT()
        await goToVerify(sut)

        sut.goBack()

        XCTAssertEqual(sut.step, .password)
        XCTAssertTrue(sut.isNavigatingBack)
    }

    func test_resume_jumpsToVerify_withSavedInfo() async {
        let info = RegistrationInfo(fullName: "Nguyễn Minh Anh", email: "minhanh@email.com", phone: "0912345678", birthDate: now)
        useCase.resumeResult = (
            SavedRegistration(id: "reg-9", info: info, createdAt: now),
            RegistrationSession(id: "reg-9", nextStep: .verifyEmail)
        )
        let sut = makeSUT()

        await sut.resumeIfNeeded()

        XCTAssertEqual(sut.step, .verify)
        XCTAssertEqual(sut.registrationId, "reg-9")
        XCTAssertEqual(sut.normalizedEmail, "minhanh@email.com")
    }

    func test_resume_verifiedSession_completesImmediately() async {
        let info = RegistrationInfo(fullName: "A", email: "a@b.co", phone: "0912345678", birthDate: now)
        useCase.resumeResult = (
            SavedRegistration(id: "reg-9", info: info, createdAt: now),
            RegistrationSession(id: "reg-9", nextStep: .complete)
        )
        let sut = makeSUT()

        await sut.resumeIfNeeded()

        XCTAssertEqual(useCase.completeCalls, 1)
        XCTAssertEqual(sut.step, .done)
    }

    func test_stepNumbers() {
        XCTAssertEqual(RegisterViewModel.Step.info.number, 1)
        XCTAssertEqual(RegisterViewModel.Step.verify.number, 3)
        XCTAssertNil(RegisterViewModel.Step.done.number)
    }
}
