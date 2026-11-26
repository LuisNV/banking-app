import Factory
import Foundation

extension Container {
    // MARK: Data
    var passwordResetRemoteDataSource: Factory<any PasswordResetRemoteDataSource> {
        self { () -> any PasswordResetRemoteDataSource in
            if self.appConfig().useMockAPI {
                return MockPasswordResetRemoteDataSource()
            }
            return PasswordResetRemoteDataSourceImpl(client: self.apiClient())
        }.singleton
    }

    var passwordResetRepository: Factory<any PasswordResetRepository> {
        self { PasswordResetRepositoryImpl(remote: self.passwordResetRemoteDataSource()) }
    }

    // MARK: Domain
    var resetPasswordUseCase: Factory<any ResetPasswordUseCaseProtocol> {
        self { ResetPasswordUseCase(repository: self.passwordResetRepository(), authRepository: self.authRepository()) }
    }
}
