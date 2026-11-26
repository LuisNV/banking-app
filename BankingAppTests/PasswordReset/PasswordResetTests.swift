import XCTest
@testable import BankingApp

// MARK: - Validator, endpoint, DTO, mã lỗi

final class PasswordResetDataTests: XCTestCase {
    func test_identifierValidation() {
        XCTAssertTrue(PasswordResetValidator.isValidIdentifier("thanh.nguyen@example.com"))
        XCTAssertTrue(PasswordResetValidator.isValidIdentifier("090 123 4567"))
        XCTAssertFalse(PasswordResetValidator.isValidIdentifier("12345"))
        XCTAssertFalse(PasswordResetValidator.isValidIdentifier("abc@"))
    }

    func test_endpoints_matchCurl() throws {
        let start = PasswordResetEndpoint.start(.init(identifier: "0901234567"))
        XCTAssertEqual(start.path, "v1/auth/password-resets")
        XCTAssertEqual(start.method.rawValue, "POST")
        XCTAssertFalse(start.requiresAuth)
        XCTAssertEqual(PasswordResetEndpoint.resendOTP(resetId: "r1").path, "v1/auth/password-resets/r1/otp/resend")
        XCTAssertNil(PasswordResetEndpoint.resendOTP(resetId: "r1").body)
        XCTAssertEqual(PasswordResetEndpoint.verify(resetId: "r1", .init(code: "123456")).path,
                       "v1/auth/password-resets/r1/verify")

        let complete = PasswordResetEndpoint.complete(resetId: "r1", .init(
            resetToken: "kQ9x", newPassword: "Matkhaumoi123", confirmPassword: "Matkhaumoi123"
        ))
        XCTAssertEqual(complete.path, "v1/auth/password-resets/r1/complete")
        let body = try XCTUnwrap(complete.body)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AnyEncodable(body))) as? [String: String]
        XCTAssertEqual(json, ["resetToken": "kQ9x", "newPassword": "Matkhaumoi123", "confirmPassword": "Matkhaumoi123"])
    }

    func test_decodeResponses() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let start = """
        {"code":0,"httpStatus":201,"message":"OK","data":{"resetId":"3f6c","identifierType":"EMAIL",
          "destination":"th••••@example.com","otpExpiresAt":"2026-11-26T03:30:00Z",
          "resendAvailableAt":"2026-11-26T03:20:45Z","remainingAttempts":5,"expiresAt":"2026-11-26T03:35:00Z"}}
        """
        let request = try XCTUnwrap(
            decoder.decode(APIResponse<PasswordResetResponseDTO>.self, from: Data(start.utf8)).data?.toDomain(fallbackId: nil)
        )
        XCTAssertEqual(request.id, "3f6c")
        XCTAssertEqual(request.destination, "th••••@example.com")
        XCTAssertEqual(request.resendAvailableAt, ISO8601DateFormatter().date(from: "2026-11-26T03:20:45Z"))

        let verify = """
        {"code":0,"httpStatus":200,"message":"OK","data":{"resetToken":"kQ9x","resetTokenExpiresAt":"2026-11-26T03:31:00Z","email":"th••@example.com"}}
        """
        let verification = try XCTUnwrap(
            decoder.decode(APIResponse<PasswordResetVerifyResponseDTO>.self, from: Data(verify.utf8)).data?.toDomain()
        )
        XCTAssertEqual(verification.token, "kQ9x")

        let complete = """
        {"code":0,"httpStatus":200,"message":"OK","data":{"revokedSessionCount":2,"notifiedEmail":"th••@example.com","biometricDisabled":true}}
        """
        let result = try XCTUnwrap(
            decoder.decode(APIResponse<PasswordResetCompleteResponseDTO>.self, from: Data(complete.utf8)).data?.toDomain()
        )
        XCTAssertEqual(result, PasswordResetResult(revokedSessionCount: 2, notifiedEmail: "th••@example.com", biometricDisabled: true))
    }

    func test_mapsErrorCodes() {
        func api(_ code: Int, _ status: Int, _ message: String = "m") -> NetworkError {
            .api(code: code, httpStatus: status, message: message, traceId: nil)
        }
        typealias Repo = PasswordResetRepositoryImpl
        XCTAssertEqual(Repo.map(api(1025, 400), in: .start), .invalidIdentifier(message: "m"))
        XCTAssertEqual(Repo.map(api(1014, 429), in: .start), .tooManyRequests(message: "m"))
        XCTAssertEqual(Repo.map(api(1014, 429), in: .resend), .sendLimitReached)
        XCTAssertEqual(Repo.map(api(409, 409), in: .resend), .alreadyVerified)
        XCTAssertEqual(Repo.map(api(1013, 429), in: .resend), .resendTooSoon(message: "m"))
        XCTAssertEqual(Repo.map(api(1010, 400, "Bạn còn 4 lần thử"), in: .verify), .invalidCode(message: "Bạn còn 4 lần thử"))
        XCTAssertEqual(Repo.map(api(1011, 400), in: .verify), .codeExpired(message: "m"))
        XCTAssertEqual(Repo.map(api(1012, 429), in: .verify), .tooManyAttempts(message: "m"))
        XCTAssertEqual(Repo.map(api(1008, 400), in: .complete), .passwordMismatch(message: "m"))
        XCTAssertEqual(Repo.map(api(1009, 400), in: .complete), .weakPassword(message: "m"))
        XCTAssertEqual(Repo.map(api(1017, 400), in: .complete), .sameAsCurrent(message: "m"))
        XCTAssertEqual(Repo.map(api(1021, 404), in: .verify), .notFound(message: "m"))
        XCTAssertEqual(Repo.map(api(1022, 410), in: .complete), .expired(message: "m"))
        XCTAssertEqual(Repo.map(api(1023, 409), in: .complete), .notVerified)
        XCTAssertEqual(Repo.map(api(1024, 403), in: .complete), .tokenInvalid)
        XCTAssertTrue(PasswordResetError.sendLimitReached.requiresRestart)
        XCTAssertTrue(PasswordResetError.expired(message: nil).requiresRestart)
        XCTAssertTrue(PasswordResetError.codeExpired(message: nil).needsNewCode)
    }

    func test_complete_discardsLocalSession() async throws {
        let auth = MockAuthRepository()
        let remote = MockPasswordResetRemoteDataSource(delay: .zero)
        let sut = ResetPasswordUseCase(repository: PasswordResetRepositoryImpl(remote: remote), authRepository: auth)

        let request = try await sut.start(identifier: "demo@tingting.vn")
        let verification = try await sut.verify(resetId: request.id, code: MockPasswordResetRemoteDataSource.validCode)
        let result = try await sut.complete(
            resetId: request.id, token: verification.token, newPassword: "Matkhaumoi123", confirmPassword: "Matkhaumoi123"
        )

        XCTAssertEqual(result.revokedSessionCount, 2)
        XCTAssertTrue(auth.discardCalled)
    }

    /// Email/SĐT chưa đăng ký: bước 1 vẫn thành công, verify luôn sai (không lộ tài khoản).
    func test_unknownAccount_alwaysInvalidCode() async throws {
        let remote = MockPasswordResetRemoteDataSource(delay: .zero)
        let started = try await remote.start(.init(identifier: "unknown@example.com"))
        do {
            _ = try await remote.verify(resetId: try XCTUnwrap(started.resetId), .init(code: MockPasswordResetRemoteDataSource.validCode))
            XCTFail("Expected 1010")
        } catch {
            guard case .invalidCode = PasswordResetRepositoryImpl.map(error, in: .verify) else {
                return XCTFail("Expected invalidCode, got \(error)")
            }
        }
    }
}

// MARK: - ViewModel

private final class StubResetUseCase: ResetPasswordUseCaseProtocol {
    var startResult: Result<PasswordResetRequest, Error> = .success(StubResetUseCase.request)
    var verifyResults: [Result<PasswordResetVerification, Error>] = []
    var completeResults: [Result<PasswordResetResult, Error>] = []
    private(set) var verifiedCodes: [String] = []
    private(set) var usedTokens: [String] = []

    static let request = PasswordResetRequest(
        id: "r1", identifierType: "EMAIL", destination: "th••@example.com",
        otpExpiresAt: Date().addingTimeInterval(600), resendAvailableAt: nil, remainingAttempts: 5, expiresAt: nil
    )

    func start(identifier: String) async throws -> PasswordResetRequest { try startResult.get() }
    func resendCode(resetId: String) async throws -> PasswordResetRequest? { nil }

    func verify(resetId: String, code: String) async throws -> PasswordResetVerification {
        verifiedCodes.append(code)
        let fallback: Result<PasswordResetVerification, Error> =
            .success(.init(token: "token-\(verifiedCodes.count)", tokenExpiresAt: nil, email: nil))
        return try (verifyResults.isEmpty ? fallback : verifyResults.removeFirst()).get()
    }

    func complete(resetId: String, token: String, newPassword: String, confirmPassword: String)
        async throws -> PasswordResetResult {
        usedTokens.append(token)
        let fallback: Result<PasswordResetResult, Error> =
            .success(.init(revokedSessionCount: 2, notifiedEmail: "th••@example.com", biometricDisabled: true))
        return try (completeResults.isEmpty ? fallback : completeResults.removeFirst()).get()
    }
}

@MainActor
final class ForgotPasswordViewModelTests: XCTestCase {
    private var useCase: StubResetUseCase!

    override func setUp() {
        super.setUp()
        useCase = StubResetUseCase()
    }

    private func makeSUT() -> ForgotPasswordViewModel {
        let sut = ForgotPasswordViewModel(useCase: useCase, sleep: { _ in throw CancellationError() })
        sut.prefill("thanh.nguyen@example.com")
        return sut
    }

    private func goToNewPassword(_ sut: ForgotPasswordViewModel) async {
        await sut.sendCode()
        sut.updateCode("123456")
        await sut.verify()
        sut.newPassword = "Matkhaumoi123"
        sut.confirmPassword = "Matkhaumoi123"
    }

    func test_invalidIdentifier_staysOnStep1() async {
        let sut = ForgotPasswordViewModel(useCase: useCase)
        sut.identifier = "12345"

        await sut.sendCode()

        XCTAssertEqual(sut.step, .identifier)
        XCTAssertNotNil(sut.identifierError)
    }

    func test_fullFlow() async {
        let sut = makeSUT()
        await sut.sendCode()
        XCTAssertEqual(sut.step, .verify)
        XCTAssertEqual(sut.destination, "th••@example.com")
        XCTAssertEqual(sut.resendSecondsLeft, ForgotPasswordViewModel.resendCooldown)

        sut.updateCode("123456")
        await sut.verify()
        XCTAssertEqual(sut.step, .newPassword)

        sut.newPassword = "Matkhaumoi123"
        sut.confirmPassword = "Matkhaumoi123"
        await sut.complete()
        XCTAssertEqual(sut.step, .done)
        XCTAssertEqual(sut.result?.revokedSessionCount, 2)
    }

    func test_codeExpired_highlightsResend() async {
        useCase.verifyResults = [.failure(PasswordResetError.codeExpired(message: "Mã xác thực đã hết hạn"))]
        let sut = makeSUT()
        await sut.sendCode()
        sut.updateCode("123456")

        await sut.verify()

        XCTAssertEqual(sut.codeError, "Mã xác thực đã hết hạn")
        XCTAssertTrue(sut.needsNewCode)
        XCTAssertEqual(sut.step, .verify)
    }

    func test_expired_returnsToStep1_keepingIdentifier() async {
        useCase.verifyResults = [.failure(PasswordResetError.expired(message: "Hết hạn"))]
        let sut = makeSUT()
        await sut.sendCode()
        sut.updateCode("123456")

        await sut.verify()

        XCTAssertEqual(sut.step, .identifier)
        XCTAssertEqual(sut.identifier, "thanh.nguyen@example.com")
        XCTAssertEqual(sut.alertMessage, "Hết hạn")
    }

    /// 1024: tự xác minh lại bằng mã cũ để lấy token mới rồi đặt mật khẩu lại.
    func test_tokenInvalid_reverifiesWithSameCode_andRetries() async {
        useCase.completeResults = [.failure(PasswordResetError.tokenInvalid)]
        let sut = makeSUT()
        await goToNewPassword(sut)

        await sut.complete()

        XCTAssertEqual(useCase.verifiedCodes, ["123456", "123456"])
        XCTAssertEqual(useCase.usedTokens, ["token-1", "token-2"])
        XCTAssertEqual(sut.step, .done)
    }

    func test_weakPassword_fromServer_showsUnderField() async {
        useCase.completeResults = [.failure(PasswordResetError.sameAsCurrent(message: "Mật khẩu mới phải khác mật khẩu hiện tại"))]
        let sut = makeSUT()
        await goToNewPassword(sut)

        await sut.complete()

        XCTAssertEqual(sut.error(for: .new), "Mật khẩu mới phải khác mật khẩu hiện tại")
        XCTAssertEqual(sut.step, .newPassword)
    }
}
