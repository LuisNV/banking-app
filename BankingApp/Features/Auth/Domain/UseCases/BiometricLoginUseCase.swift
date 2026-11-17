import Foundation

protocol BiometricLoginUseCaseProtocol {
    func execute() async throws -> AuthSession
}

struct BiometricLoginUseCase: BiometricLoginUseCaseProtocol {
    let repository: AuthRepository
    let biometricService: BiometricAuthService

    func execute() async throws -> AuthSession {
        let type = biometricService.availableType
        guard type != .none else { throw AuthError.biometricUnavailable }
        guard repository.hasStoredSession() else { throw AuthError.biometricNotEnrolled }

        let success: Bool
        do {
            success = try await biometricService.authenticate(
                reason: "Xác thực bằng \(type.displayName) để đăng nhập"
            )
        } catch {
            throw AuthError.biometricFailed
        }
        guard success else { throw AuthError.biometricFailed }

        return try await repository.restoreSession()
    }
}
