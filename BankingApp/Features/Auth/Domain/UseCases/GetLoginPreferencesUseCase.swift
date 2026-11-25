import Foundation

protocol GetLoginPreferencesUseCaseProtocol {
    func execute() -> LoginPreferences
}

struct GetLoginPreferencesUseCase: GetLoginPreferencesUseCaseProtocol {
    let repository: AuthRepository
    let biometricService: BiometricAuthService

    func execute() -> LoginPreferences {
        let type = biometricService.availableType
        return LoginPreferences(
            rememberedUsername: repository.rememberedUsername(),
            biometricType: type,
            canUseBiometricLogin: type != .none
                && repository.isBiometricLoginEnabled()
                && repository.hasStoredSession()
        )
    }
}
