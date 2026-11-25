import Foundation

protocol ChangePasswordUseCaseProtocol {
    func start(currentPassword: String, newPassword: String, confirmPassword: String, logoutOtherDevices: Bool)
        async throws -> PasswordChangeRequest
    func resendCode(requestId: String) async throws -> PasswordChangeRequest?
    func verify(requestId: String, code: String) async throws -> PasswordChangeResult
}

struct ChangePasswordUseCase: ChangePasswordUseCaseProtocol {
    static let codeLength = 6

    let repository: PasswordChangeRepository

    func start(currentPassword: String, newPassword: String, confirmPassword: String, logoutOtherDevices: Bool)
        async throws -> PasswordChangeRequest {
        let errors = PasswordChangeValidator.errors(current: currentPassword, new: newPassword, confirm: confirmPassword)
        guard errors.isEmpty else { throw PasswordChangeError.invalid(errors) }
        return try await repository.start(
            currentPassword: currentPassword,
            newPassword: newPassword,
            confirmPassword: confirmPassword,
            logoutOtherDevices: logoutOtherDevices
        )
    }

    func resendCode(requestId: String) async throws -> PasswordChangeRequest? {
        try await repository.resendCode(requestId: requestId)
    }

    func verify(requestId: String, code: String) async throws -> PasswordChangeResult {
        guard code.count == Self.codeLength, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw PasswordChangeError.invalidCode(message: nil)
        }
        return try await repository.verify(requestId: requestId, code: code)
    }
}
