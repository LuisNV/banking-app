import XCTest
@testable import BankingApp

// MARK: - Validator

final class PasswordChangeValidatorTests: XCTestCase {
    func test_valid() {
        XCTAssertTrue(PasswordChangeValidator.errors(current: "OldPass123", new: "NewPass456", confirm: "NewPass456").isEmpty)
    }

    func test_weak_mismatch_sameAsCurrent() {
        XCTAssertNotNil(PasswordChangeValidator.errors(current: "OldPass123", new: "newpass", confirm: "newpass")[.new])
        XCTAssertNotNil(PasswordChangeValidator.errors(current: "OldPass123", new: "NewPass456", confirm: "NewPass457")[.confirm])
        XCTAssertEqual(
            PasswordChangeValidator.errors(current: "OldPass123", new: "OldPass123", confirm: "OldPass123")[.new],
            "Mật khẩu mới phải khác mật khẩu hiện tại."
        )
    }

    func test_over72BytesUTF8_isRejected() {
        // 70 ký tự ASCII + "ệ" (3 byte) = 73 byte.
        let long = "Aa1" + String(repeating: "x", count: 67) + "ệ"
        XCTAssertEqual(long.count, 71)
        XCTAssertNotNil(PasswordChangeValidator.errors(current: "OldPass123", new: long, confirm: long)[.new])
    }
}

// MARK: - Endpoint, DTO, mã lỗi

final class PasswordChangeDataTests: XCTestCase {
    func test_endpoints_matchCurl() throws {
        let start = PasswordChangeEndpoint.start(.init(
            currentPassword: "OldPass123", newPassword: "NewPass456", confirmPassword: "NewPass456", logoutOtherDevices: true
        ))
        XCTAssertEqual(start.path, "v1/auth/password-changes")
        XCTAssertEqual(start.method.rawValue, "POST")
        XCTAssertTrue(start.requiresAuth)

        let body = try XCTUnwrap(start.body)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AnyEncodable(body))) as? NSDictionary
        XCTAssertEqual(json, [
            "currentPassword": "OldPass123", "newPassword": "NewPass456",
            "confirmPassword": "NewPass456", "logoutOtherDevices": true,
        ] as NSDictionary)

        XCTAssertEqual(PasswordChangeEndpoint.resendOTP(requestId: "abc").path, "v1/auth/password-changes/abc/otp/resend")
        XCTAssertNil(PasswordChangeEndpoint.resendOTP(requestId: "abc").body)
        XCTAssertEqual(PasswordChangeEndpoint.verify(requestId: "abc", .init(code: "123456")).path,
                       "v1/auth/password-changes/abc/verify")
    }

    func test_decode_startAndVerifyResponses() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let start = """
        {"code":0,"httpStatus":201,"message":"OK","data":{"requestId":"7c1e","email":"user@example.com",
          "logoutOtherDevices":true,"otpExpiresAt":"2026-11-25T10:25:00Z","resendAvailableAt":"2026-11-25T10:15:45Z",
          "remainingAttempts":5,"expiresAt":"2026-11-25T10:30:00Z"}}
        """
        let dto = try XCTUnwrap(decoder.decode(APIResponse<PasswordChangeResponseDTO>.self, from: Data(start.utf8)).data)
        let request = try XCTUnwrap(dto.toDomain(fallbackId: nil, fallbackLogout: false))
        XCTAssertEqual(request.id, "7c1e")
        XCTAssertEqual(request.email, "user@example.com")
        XCTAssertTrue(request.logoutOtherDevices)
        XCTAssertEqual(request.remainingAttempts, 5)
        XCTAssertEqual(request.resendAvailableAt, ISO8601DateFormatter().date(from: "2026-11-25T10:15:45Z"))

        let verify = """
        {"code":0,"httpStatus":200,"message":"OK","data":{"loggedOutOtherDevices":true,"revokedSessionCount":2}}
        """
        let result = try XCTUnwrap(decoder.decode(APIResponse<PasswordChangeVerifyResponseDTO>.self, from: Data(verify.utf8)).data)
        XCTAssertEqual(result.toDomain(), PasswordChangeResult(loggedOutOtherDevices: true, revokedSessionCount: 2))
    }

    func test_mapsErrors() {
        func api(_ code: Int, _ status: Int, _ message: String = "m") -> NetworkError {
            .api(code: code, httpStatus: status, message: message, traceId: nil)
        }
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(api(1002, 400, "Bạn còn 4 lần thử")),
                       .wrongCurrentPassword(message: "Bạn còn 4 lần thử"))
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(api(1018, 429, "thử lại sau 15 phút")),
                       .locked(message: "thử lại sau 15 phút"))
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(api(1010, 400, "Bạn còn 3 lần thử")),
                       .invalidCode(message: "Bạn còn 3 lần thử"))
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(api(1013, 429, "Vui lòng chờ 20 giây")),
                       .resendTooSoon(message: "Vui lòng chờ 20 giây"))
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(api(APIResponseMeta.namedErrorCode, 410, "Hết hạn")), .requestExpired)
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(api(APIResponseMeta.namedErrorCode, 409, "Phiên không xác định")),
                       .api(message: "Phiên không xác định"))
        XCTAssertEqual(PasswordChangeRepositoryImpl.map(NetworkError.unauthorized), .sessionExpired)
        XCTAssertEqual(PasswordChangeError.locked(message: "Vui lòng thử lại sau 12 phút").lockMinutes, 12)
    }

    func test_apiMeta_acceptsStringCode() throws {
        let json = #"{"code":"SESSION_UNKNOWN","httpStatus":409,"message":"Phiên không xác định"}"#
        let meta = try JSONDecoder().decode(APIResponseMeta.self, from: Data(json.utf8))
        XCTAssertEqual(meta.code, APIResponseMeta.namedErrorCode)
        XCTAssertEqual(meta.message, "Phiên không xác định")
    }

    func test_networkLog_redactsEveryPasswordField() {
        let body = #"{"currentPassword":"OldPass123","newPassword":"NewPass456","confirmPassword":"NewPass456","password":"x","code":"1"}"#
        let redacted = NetworkLogger.redactPassword(body)
        XCTAssertFalse(redacted.contains("OldPass123"))
        XCTAssertFalse(redacted.contains("NewPass456"))
        XCTAssertTrue(redacted.contains(#""currentPassword":"***""#))
        XCTAssertTrue(redacted.contains(#""code":"1""#))
    }

    func test_mockBackend_flow() async throws {
        let remote = MockPasswordChangeRemoteDataSource(delay: .zero)
        let started = try await remote.start(.init(
            currentPassword: MockPasswordChangeRemoteDataSource.currentPassword,
            newPassword: "NewPass456", confirmPassword: "NewPass456", logoutOtherDevices: true
        ))
        let id = try XCTUnwrap(started.requestId)
        let result = try await remote.verify(requestId: id, .init(code: MockPasswordChangeRemoteDataSource.validCode))
        XCTAssertEqual(result.revokedSessionCount, 2)
    }
}

// MARK: - ViewModel

private final class StubChangePasswordUseCase: ChangePasswordUseCaseProtocol {
    var startResults: [Result<PasswordChangeRequest, Error>] = []
    var verifyResults: [Result<PasswordChangeResult, Error>] = []
    var resendResult: Result<PasswordChangeRequest?, Error> = .success(nil)
    private(set) var startCalls: [Bool] = []
    private(set) var verifyCalls: [String] = []

    static let request = PasswordChangeRequest(
        id: "req-1", email: "user@example.com", logoutOtherDevices: true,
        otpExpiresAt: nil, resendAvailableAt: nil, remainingAttempts: 5, expiresAt: nil
    )

    func start(currentPassword: String, newPassword: String, confirmPassword: String, logoutOtherDevices: Bool)
        async throws -> PasswordChangeRequest {
        startCalls.append(logoutOtherDevices)
        return try (startResults.isEmpty ? .success(Self.request) : startResults.removeFirst()).get()
    }

    func resendCode(requestId: String) async throws -> PasswordChangeRequest? { try resendResult.get() }

    func verify(requestId: String, code: String) async throws -> PasswordChangeResult {
        verifyCalls.append(code)
        let fallback: Result<PasswordChangeResult, Error> = .success(.init(loggedOutOtherDevices: true, revokedSessionCount: 2))
        return try (verifyResults.isEmpty ? fallback : verifyResults.removeFirst()).get()
    }
}

@MainActor
final class ChangePasswordViewModelTests: XCTestCase {
    private var useCase: StubChangePasswordUseCase!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        useCase = StubChangePasswordUseCase()
    }

    private func makeSUT() -> ChangePasswordViewModel {
        let sut = ChangePasswordViewModel(useCase: useCase, now: { [now] in now }, sleep: { _ in throw CancellationError() })
        sut.currentPassword = "OldPass123"
        sut.newPassword = "NewPass456"
        sut.confirmPassword = "NewPass456"
        return sut
    }

    func test_submit_goesToVerify_withCountdown() async {
        let sut = makeSUT()

        await sut.submit()

        XCTAssertEqual(useCase.startCalls, [true])
        XCTAssertEqual(sut.step, .verify)
        XCTAssertEqual(sut.email, "user@example.com")
        XCTAssertEqual(sut.resendSecondsLeft, ChangePasswordViewModel.resendCooldown)
    }

    func test_invalidForm_doesNotCallServer() async {
        let sut = makeSUT()
        sut.confirmPassword = "Khac123456"

        await sut.submit()

        XCTAssertTrue(useCase.startCalls.isEmpty)
        XCTAssertNotNil(sut.error(for: .confirm))
        XCTAssertEqual(sut.step, .form)
    }

    func test_wrongCurrentPassword_clearsField_andShowsServerMessage() async {
        useCase.startResults = [.failure(PasswordChangeError.wrongCurrentPassword(message: "Mật khẩu hiện tại không đúng. Bạn còn 4 lần thử"))]
        let sut = makeSUT()

        await sut.submit()

        XCTAssertEqual(sut.currentPassword, "")
        XCTAssertEqual(sut.error(for: .current), "Mật khẩu hiện tại không đúng. Bạn còn 4 lần thử")
        XCTAssertEqual(sut.step, .form)
    }

    func test_locked_disablesSubmit() async {
        useCase.startResults = [.failure(PasswordChangeError.locked(message: "Vui lòng thử lại sau 15 phút"))]
        let sut = makeSUT()

        await sut.submit()

        XCTAssertTrue(sut.isLocked)
        XCTAssertFalse(sut.canSubmit)
        sut.didEdit(.current)
        XCTAssertEqual(sut.error(for: .current), "Vui lòng thử lại sau 15 phút", "Đang khoá thì giữ thông báo")
    }

    func test_verify_success_showsResult() async {
        let sut = makeSUT()
        await sut.submit()
        sut.updateCode("123456")

        await sut.verify()

        XCTAssertEqual(sut.step, .done)
        XCTAssertEqual(sut.result?.revokedSessionCount, 2)
    }

    func test_verify_wrongCode_showsErrorUnderCode() async {
        useCase.verifyResults = [.failure(PasswordChangeError.invalidCode(message: "Mã không đúng. Bạn còn 4 lần thử"))]
        let sut = makeSUT()
        await sut.submit()
        sut.updateCode("000000")

        await sut.verify()

        XCTAssertEqual(sut.code, "")
        XCTAssertEqual(sut.codeError, "Mã không đúng. Bạn còn 4 lần thử")
        XCTAssertEqual(sut.step, .verify)
    }

    func test_requestExpired_returnsToForm_keepingPasswords() async {
        useCase.verifyResults = [.failure(PasswordChangeError.requestExpired)]
        let sut = makeSUT()
        await sut.submit()
        sut.updateCode("123456")

        await sut.verify()

        XCTAssertEqual(sut.step, .form)
        XCTAssertEqual(sut.newPassword, "NewPass456")
        XCTAssertEqual(sut.alertMessage, PasswordChangeError.requestExpired.errorDescription)
    }
}
