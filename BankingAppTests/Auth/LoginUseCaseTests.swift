import XCTest
@testable import BankingApp

final class LoginUseCaseTests: XCTestCase {
    private var repository: MockAuthRepository!
    private var sut: LoginUseCase!

    override func setUp() {
        super.setUp()
        repository = MockAuthRepository()
        sut = LoginUseCase(repository: repository)
    }

    func test_emptyUsername_throwsValidationError() async {
        do {
            _ = try await sut.execute(username: "   ", password: "123456", rememberUsername: true)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .emptyUsername)
        }
        XCTAssertTrue(repository.loginCalls.isEmpty)
    }

    func test_shortPassword_throwsValidationError() async {
        do {
            _ = try await sut.execute(username: "demo", password: "123", rememberUsername: true)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidPassword)
        }
    }

    func test_success_trimsUsername_andRemembersIt() async throws {
        _ = try await sut.execute(username: "  demo ", password: "123456", rememberUsername: true)
        XCTAssertEqual(repository.loginCalls.first?.0, "demo")
        XCTAssertEqual(repository.savedUsername, "demo")
    }

    func test_success_withoutRemember_clearsSavedUsername() async throws {
        repository.savedUsername = "old"
        _ = try await sut.execute(username: "demo", password: "123456", rememberUsername: false)
        XCTAssertNil(repository.savedUsername)
    }
}

final class BiometricLoginUseCaseTests: XCTestCase {
    func test_noBiometrics_throwsUnavailable() async {
        let biometrics = MockBiometricAuthService()
        biometrics.availableType = .none
        let sut = BiometricLoginUseCase(repository: MockAuthRepository(), biometricService: biometrics)
        do {
            _ = try await sut.execute()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricUnavailable)
        }
    }

    func test_noStoredSession_throwsNotEnrolled() async {
        let repository = MockAuthRepository()
        repository.storedSession = false
        let sut = BiometricLoginUseCase(repository: repository, biometricService: MockBiometricAuthService())
        do {
            _ = try await sut.execute()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricNotEnrolled)
        }
    }

    func test_authenticated_restoresSession() async throws {
        let sut = BiometricLoginUseCase(repository: MockAuthRepository(), biometricService: MockBiometricAuthService())
        let session = try await sut.execute()
        XCTAssertEqual(session, .stub())
    }
}

final class LoginIdentifierTests: XCTestCase {
    func test_email_isTrimmedAndLowercased() {
        XCTAssertEqual(LoginUseCase.normalizedIdentifier("  User@Example.com "), "user@example.com")
    }

    func test_phone_isDigitsOnly() {
        XCTAssertEqual(LoginUseCase.normalizedIdentifier("091 234 5678"), "0912345678")
        XCTAssertEqual(LoginUseCase.normalizedIdentifier("+84 912 345 678"), "0912345678")
    }

    func test_otherUsername_isOnlyTrimmed() {
        XCTAssertEqual(LoginUseCase.normalizedIdentifier(" demo "), "demo")
    }
}
