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

final class MockRegistrationRepositoryTests: XCTestCase {
    private let sut = MockRegistrationRepository(delay: .zero)

    func test_takenEmail_throws() async {
        do {
            try await sut.createAccount(makeInfo(email: MockRegistrationRepository.takenEmail), password: "Tingting1")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .emailTaken)
        }
    }

    func test_verify_onlyAcceptsValidCode() async throws {
        try await sut.verifyEmail(email: "a@b.com", code: MockRegistrationRepository.validCode)
        do {
            try await sut.verifyEmail(email: "a@b.com", code: "000000")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .invalidCode)
        }
    }
}

final class RegisterUseCaseTests: XCTestCase {
    private final class SpyRepository: RegistrationRepository {
        private(set) var created: [(RegistrationInfo, String)] = []
        private(set) var verified: [(String, String)] = []

        func createAccount(_ info: RegistrationInfo, password: String) async throws { created.append((info, password)) }
        func verifyEmail(email: String, code: String) async throws { verified.append((email, code)) }
        func resendCode(email: String) async throws {}
    }

    func test_createAccount_sendsNormalizedInfo() async throws {
        let repository = SpyRepository()
        let sut = RegisterUseCase(repository: repository)

        try await sut.createAccount(info: makeInfo(email: " MinhAnh@Email.com "), password: "Tingting1")

        XCTAssertEqual(repository.created.first?.0.email, "minhanh@email.com")
        XCTAssertEqual(repository.created.first?.1, "Tingting1")
    }

    func test_createAccount_invalidInfo_doesNotCallRepository() async {
        let repository = SpyRepository()
        let sut = RegisterUseCase(repository: repository)
        do {
            try await sut.createAccount(info: makeInfo(email: "bad"), password: "Tingting1")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .invalidInfo)
        }
        XCTAssertTrue(repository.created.isEmpty)
    }

    func test_createAccount_weakPassword_throws() async {
        let sut = RegisterUseCase(repository: SpyRepository())
        do {
            try await sut.createAccount(info: makeInfo(), password: "abc")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .weakPassword)
        }
    }

    func test_verify_rejectsMalformedCode() async {
        let repository = SpyRepository()
        let sut = RegisterUseCase(repository: repository)
        do {
            try await sut.verifyEmail(email: "a@b.com", code: "12a456")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? RegisterError, .invalidCode)
        }
        XCTAssertTrue(repository.verified.isEmpty)
    }
}
