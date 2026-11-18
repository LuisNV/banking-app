import Foundation

protocol RegisterUseCaseProtocol {
    func createAccount(info: RegistrationInfo, password: String) async throws
    func verifyEmail(email: String, code: String) async throws
    func resendCode(email: String) async throws
}

struct RegisterUseCase: RegisterUseCaseProtocol {
    static let codeLength = 6

    let repository: RegistrationRepository
    var now: () -> Date = Date.init

    func createAccount(info: RegistrationInfo, password: String) async throws {
        guard RegistrationValidator.errors(for: info, now: now()).isEmpty else { throw RegisterError.invalidInfo }
        guard PasswordEvaluation.evaluate(password).meetsRequirements else { throw RegisterError.weakPassword }
        try await repository.createAccount(info.normalized, password: password)
    }

    func verifyEmail(email: String, code: String) async throws {
        guard code.count == Self.codeLength, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw RegisterError.invalidCode
        }
        try await repository.verifyEmail(email: RegistrationValidator.normalizedEmail(email), code: code)
    }

    func resendCode(email: String) async throws {
        try await repository.resendCode(email: RegistrationValidator.normalizedEmail(email))
    }
}
