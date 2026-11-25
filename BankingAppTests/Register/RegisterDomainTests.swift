import XCTest
@testable import BankingApp

private func makeInfo(
    fullName: String = "Nguyễn Minh Anh",
    email: String = "minhanh@email.com",
    phone: String = "0912345678",
    birthDate: Date = Date(timeIntervalSince1970: 946_684_800)
) -> RegistrationInfo {
    RegistrationInfo(fullName: fullName, email: email, phone: phone, birthDate: birthDate)
}

final class RegistrationValidatorTests: XCTestCase {
    func test_validInfo_hasNoErrors() {
        XCTAssertTrue(RegistrationValidator.errors(for: makeInfo()).isEmpty)
    }

    func test_emptyFields_reportEachField() {
        let errors = RegistrationValidator.errors(for: makeInfo(fullName: " ", email: "", phone: ""))
        XCTAssertEqual(Set(errors.keys), [.fullName, .email, .phone])
    }

    func test_invalidEmail() {
        XCTAssertEqual(RegistrationValidator.errors(for: makeInfo(email: "minhanh@"))[.email], "Email không hợp lệ.")
    }

    func test_phone_mustHave10DigitsStartingWith0() {
        XCTAssertNotNil(RegistrationValidator.errors(for: makeInfo(phone: "091234567"))[.phone])
        XCTAssertNotNil(RegistrationValidator.errors(for: makeInfo(phone: "1912345678"))[.phone])
        XCTAssertNil(RegistrationValidator.errors(for: makeInfo(phone: "091 234 5678"))[.phone])
    }

    func test_phone_acceptsVietnamCountryCode() {
        XCTAssertEqual(RegistrationValidator.normalizedPhone("+84 912 345 678"), "0912345678")
    }

    func test_birthDateInFuture_isInvalid() {
        let now = Date()
        let errors = RegistrationValidator.errors(for: makeInfo(birthDate: now.addingTimeInterval(86_400)), now: now)
        XCTAssertNotNil(errors[.birthDate])
    }

    func test_normalized_trimsAndLowercases() {
        let info = makeInfo(fullName: "  Nguyễn   Minh  Anh ", email: " MinhAnh@Email.com ", phone: "091 234 5678").normalized
        XCTAssertEqual(info.fullName, "Nguyễn Minh Anh")
        XCTAssertEqual(info.email, "minhanh@email.com")
        XCTAssertEqual(info.phone, "0912345678")
    }
}

final class PasswordEvaluationTests: XCTestCase {
    func test_empty() {
        XCTAssertEqual(PasswordEvaluation.evaluate("").strength, .empty)
    }

    func test_missingRequirements_isWeak() {
        let evaluation = PasswordEvaluation.evaluate("abcdefgh")
        XCTAssertFalse(evaluation.meetsRequirements)
        XCTAssertEqual(evaluation.strength, .weak)
    }

    func test_meetsRequirements_isMedium() {
        let evaluation = PasswordEvaluation.evaluate("Tingting1")
        XCTAssertTrue(evaluation.meetsRequirements)
        XCTAssertFalse(evaluation.hasSpecialCharacter)
        XCTAssertEqual(evaluation.strength, .medium)
    }

    func test_specialCharacterOrLength_isStrong() {
        XCTAssertEqual(PasswordEvaluation.evaluate("Tingting1!").strength, .strong)
        XCTAssertEqual(PasswordEvaluation.evaluate("Tingting2024ab").strength, .strong)
    }
}

// MARK: - Doubles

final class SpyRegistrationRepository: RegistrationRepository {
    var startResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .setPassword))
    var initiateResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .verifyEmail))
    var verifyResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .complete))
    var changeEmailResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .verifyEmail))
    var completeResult: Result<RegistrationResult, Error> = .success(
        RegistrationResult(session: .stub(username: "minhanh@email.com"), biometricEnabled: true)
    )
    var statusResult: Result<RegistrationSession, Error> = .success(RegistrationSession(id: "reg-1", nextStep: .verifyEmail))
    var saved: SavedRegistration?

    private(set) var startedInfo: [RegistrationInfo] = []
    private(set) var initiateCalls = 0
    private(set) var verifyCalls = 0
    private(set) var changedEmails: [String] = []

    func start(_ info: RegistrationInfo) async throws -> RegistrationSession {
        startedInfo.append(info)
        return try startResult.get()
    }

    func initiate(id: String, password: String, confirmPassword: String, biometricEnabled: Bool) async throws -> RegistrationSession {
        initiateCalls += 1
        return try initiateResult.get()
    }

    func verify(id: String, code: String) async throws -> RegistrationSession {
        verifyCalls += 1
        return try verifyResult.get()
    }

    func resendCode(id: String) async throws -> RegistrationSession { try initiateResult.get() }

    func changeEmail(id: String, email: String) async throws -> RegistrationSession {
        changedEmails.append(email)
        return try changeEmailResult.get()
    }

    func complete(id: String) async throws -> RegistrationResult { try completeResult.get() }
    func status(id: String) async throws -> RegistrationSession { try statusResult.get() }
    func savedRegistration() -> SavedRegistration? { saved }
    func saveRegistration(_ registration: SavedRegistration?) { saved = registration }
}

// MARK: - Use case

final class RegisterUseCaseTests: XCTestCase {
    private var repository: SpyRegistrationRepository!
    private var auth: MockAuthRepository!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        repository = SpyRegistrationRepository()
        auth = MockAuthRepository()
    }

    private func makeSUT() -> RegisterUseCase {
        RegisterUseCase(repository: repository, authRepository: auth, now: { [now] in now })
    }

    func test_start_sendsNormalizedInfo_andSavesSession() async throws {
        let session = try await makeSUT().start(
            info: makeInfo(fullName: " Nguyễn Minh Anh ", email: " MinhAnh@Email.com ", phone: "091 234 5678")
        )

        XCTAssertEqual(session.id, "reg-1")
        XCTAssertEqual(repository.startedInfo.first?.email, "minhanh@email.com")
        XCTAssertEqual(repository.startedInfo.first?.phone, "0912345678")
        XCTAssertEqual(repository.saved?.id, "reg-1")
        XCTAssertEqual(repository.saved?.createdAt, now)
    }

    func test_start_invalidInfo_doesNotCallServer() async {
        do {
            _ = try await makeSUT().start(info: makeInfo(email: "abc"))
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .invalidInfo)
        }
        XCTAssertTrue(repository.startedInfo.isEmpty)
    }

    func test_start_fullNameOver150_isInvalid() {
        let errors = RegistrationValidator.errors(for: makeInfo(fullName: String(repeating: "a", count: 151)))
        XCTAssertNotNil(errors[.fullName])
    }

    func test_setPassword_weakOrMismatch_doesNotCallServer() async {
        let sut = makeSUT()
        do {
            _ = try await sut.setPassword(id: "reg-1", password: "abc", confirmPassword: "abc", biometricEnabled: true)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .weakPassword)
        }
        do {
            _ = try await sut.setPassword(id: "reg-1", password: "Matkhau123", confirmPassword: "Matkhau124", biometricEnabled: true)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .passwordMismatch)
        }
        XCTAssertEqual(repository.initiateCalls, 0)
    }

    func test_verify_rejectsMalformedCode() async {
        do {
            _ = try await makeSUT().verify(id: "reg-1", code: "12ab56")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .invalidCode(message: nil))
        }
        XCTAssertEqual(repository.verifyCalls, 0)
    }

    func test_sessionExpired_clearsSavedSession() async {
        repository.saved = SavedRegistration(id: "reg-1", info: makeInfo(), createdAt: now)
        repository.initiateResult = .failure(RegisterError.sessionExpired)
        do {
            _ = try await makeSUT().setPassword(id: "reg-1", password: "Matkhau123", confirmPassword: "Matkhau123", biometricEnabled: false)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .sessionExpired)
        }
        XCTAssertNil(repository.saved)
    }

    func test_changeEmail_normalizes_andUpdatesSavedInfo() async throws {
        repository.saved = SavedRegistration(id: "reg-1", info: makeInfo(), createdAt: now)

        _ = try await makeSUT().changeEmail(id: "reg-1", email: " Moi@Gmail.com ")

        XCTAssertEqual(repository.changedEmails, ["moi@gmail.com"])
        XCTAssertEqual(repository.saved?.info.email, "moi@gmail.com")
    }

    func test_complete_savesTokens_biometric_andClearsSession() async throws {
        repository.saved = SavedRegistration(id: "reg-1", info: makeInfo(), createdAt: now)
        auth.biometricLoginEnabled = false

        let session = try await makeSUT().complete(id: "reg-1")

        XCTAssertEqual(auth.savedSessions, [session])
        XCTAssertTrue(auth.biometricLoginEnabled)
        XCTAssertEqual(auth.savedUsername, "minhanh@email.com")
        XCTAssertNil(repository.saved)
    }

    func test_resume_returnsSavedSessionWithServerStep() async {
        repository.saved = SavedRegistration(id: "reg-1", info: makeInfo(), createdAt: now.addingTimeInterval(-600))

        let resumed = await makeSUT().resume()

        XCTAssertEqual(resumed?.session.nextStep, .verifyEmail)
        XCTAssertEqual(resumed?.saved.info.email, "minhanh@email.com")
    }

    func test_resume_after60Minutes_discards() async {
        repository.saved = SavedRegistration(id: "reg-1", info: makeInfo(), createdAt: now.addingTimeInterval(-3_600))

        let resumed = await makeSUT().resume()

        XCTAssertNil(resumed)
        XCTAssertNil(repository.saved)
    }

    func test_resume_sessionNotFound_discards() async {
        repository.saved = SavedRegistration(id: "reg-1", info: makeInfo(), createdAt: now)
        repository.statusResult = .failure(RegisterError.sessionNotFound)

        let resumed = await makeSUT().resume()

        XCTAssertNil(resumed)
        XCTAssertNil(repository.saved)
    }
}

// MARK: - Repository (DTO, endpoint, mã lỗi)

final class RegistrationRepositoryTests: XCTestCase {
    func test_endpoints_matchCurl() {
        XCTAssertEqual(RegistrationEndpoint.start(.init(fullName: "", email: "", phone: "", dateOfBirth: nil)).path,
                       "v1/auth/registrations")
        XCTAssertEqual(RegistrationEndpoint.initiate(id: "abc", .init(password: "", confirmPassword: "", biometricEnabled: true)).path,
                       "v1/auth/registrations/abc/initiate")
        XCTAssertEqual(RegistrationEndpoint.verify(id: "abc", .init(code: "")).path, "v1/auth/registrations/abc/verify")
        XCTAssertEqual(RegistrationEndpoint.resendOTP(id: "abc").path, "v1/auth/registrations/abc/otp/resend")
        XCTAssertEqual(RegistrationEndpoint.changeEmail(id: "abc", .init(email: "")).path, "v1/auth/registrations/abc/email")
        XCTAssertEqual(RegistrationEndpoint.complete(id: "abc").path, "v1/auth/registrations/abc/complete")
        XCTAssertEqual(RegistrationEndpoint.status(id: "abc").path, "v1/auth/registrations/abc")

        XCTAssertEqual(RegistrationEndpoint.changeEmail(id: "abc", .init(email: "")).method.rawValue, "PUT")
        XCTAssertEqual(RegistrationEndpoint.status(id: "abc").method.rawValue, "GET")
        XCTAssertEqual(RegistrationEndpoint.complete(id: "abc").method.rawValue, "POST")
        XCTAssertFalse(RegistrationEndpoint.complete(id: "abc").requiresAuth)
    }

    func test_startBody_matchesCurl() throws {
        let dto = RegistrationStartRequestDTO(
            fullName: "Nguyễn Minh Anh", email: "minhanh@gmail.com", phone: "0912345678", dateOfBirth: "2002-03-12"
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: String]
        XCTAssertEqual(json, [
            "fullName": "Nguyễn Minh Anh", "email": "minhanh@gmail.com",
            "phone": "0912345678", "dateOfBirth": "2002-03-12",
        ])
    }

    func test_decode_initiateResponse() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let json = """
        {"code":0,"httpStatus":200,"message":"OK","data":{
          "registrationId":"9b2f","status":"OTP_SENT","nextStep":"VERIFY_EMAIL",
          "otpExpiresAt":"2026-11-25T10:25:00.123Z","resendAvailableAt":"2026-11-25T10:15:45Z","remainingAttempts":5}}
        """
        let dto = try XCTUnwrap(decoder.decode(APIResponse<RegistrationResponseDTO>.self, from: Data(json.utf8)).data)
        let session = try dto.toDomain(fallbackId: nil)

        XCTAssertEqual(session.id, "9b2f")
        XCTAssertEqual(session.nextStep, .verifyEmail)
        XCTAssertEqual(session.otp?.remainingAttempts, 5)
        XCTAssertEqual(session.otp?.resendAvailableAt, ISO8601DateFormatter().date(from: "2026-11-25T10:15:45Z"))
        XCTAssertNotNil(session.otp?.expiresAt)
    }

    func test_decode_completeResponse() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let json = """
        {"code":0,"httpStatus":200,"message":"OK","data":{
          "user":{"id":2,"fullName":"Nguyễn Minh Anh","email":"minhanh@gmail.com","phone":"0912345678","emailVerified":true},
          "biometricEnabled":true,
          "tokens":{"accessToken":"a","refreshToken":"r","tokenType":"Bearer","expiresIn":900}}}
        """
        let dto = try XCTUnwrap(decoder.decode(APIResponse<RegistrationCompleteDTO>.self, from: Data(json.utf8)).data)
        let result = dto.toDomain()

        XCTAssertEqual(result.session.accessToken, "a")
        XCTAssertEqual(result.session.refreshToken, "r")
        XCTAssertEqual(result.session.user, User(id: "2", fullName: "Nguyễn Minh Anh", username: "minhanh@gmail.com"))
        XCTAssertTrue(result.biometricEnabled)
    }

    func test_mapsServerCodes() {
        func api(_ code: Int, _ status: Int, _ message: String = "m") -> NetworkError {
            .api(code: code, httpStatus: status, message: message, traceId: nil)
        }
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1003, 409)), .emailTaken)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1004, 409)), .phoneTaken)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1005, 404)), .sessionNotFound)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1006, 410)), .sessionExpired)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1007, 409)), .wrongStep)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1008, 400)), .passwordMismatch)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1009, 400)), .weakPassword)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1010, 400, "Bạn còn 3 lần thử")),
                       .invalidCode(message: "Bạn còn 3 lần thử"))
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1011, 400)), .codeExpired)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1012, 429)), .tooManyAttempts)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1013, 429, "Vui lòng chờ 20 giây")),
                       .resendTooSoon(message: "Vui lòng chờ 20 giây"))
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(1014, 429)), .sendLimitReached)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(502, 502)), .emailDeliveryFailed)
        XCTAssertEqual(RegistrationRepositoryImpl.map(api(503, 503)), .emailServiceUnavailable)
        XCTAssertEqual(RegistrationRepositoryImpl.map(NetworkError.noConnection), .network)
    }

    func test_mockBackend_fullFlow() async throws {
        let remote = MockRegistrationRemoteDataSource(delay: .zero)
        let started = try await remote.start(.init(fullName: "A", email: "a@b.co", phone: "0912345678", dateOfBirth: nil))
        let id = try XCTUnwrap(started.registrationId)

        let initiated = try await remote.initiate(id: id, .init(password: "Matkhau123", confirmPassword: "Matkhau123", biometricEnabled: true))
        XCTAssertEqual(initiated.nextStep, "VERIFY_EMAIL")

        do {
            _ = try await remote.verify(id: id, .init(code: "000000"))
            XCTFail("Expected wrong code")
        } catch {
            XCTAssertEqual(RegistrationRepositoryImpl.map(error), .invalidCode(message: "Mã không đúng. Bạn còn 4 lần thử"))
        }

        let verified = try await remote.verify(id: id, .init(code: MockRegistrationRemoteDataSource.validCode))
        XCTAssertEqual(verified.nextStep, "COMPLETE")

        let completed = try await remote.complete(id: id)
        XCTAssertEqual(completed.biometricEnabled, true)
    }
}
