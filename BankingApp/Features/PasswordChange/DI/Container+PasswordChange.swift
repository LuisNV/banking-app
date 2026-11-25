import Factory
import Foundation

extension Container {
    // MARK: Data
    var passwordChangeRemoteDataSource: Factory<any PasswordChangeRemoteDataSource> {
        self { () -> any PasswordChangeRemoteDataSource in
            if self.appConfig().useMockAPI {
                return MockPasswordChangeRemoteDataSource()
            }
            return PasswordChangeRemoteDataSourceImpl(client: self.apiClient())
        }.singleton
    }

    var passwordChangeRepository: Factory<any PasswordChangeRepository> {
        self { PasswordChangeRepositoryImpl(remote: self.passwordChangeRemoteDataSource()) }
    }

    // MARK: Domain
    var changePasswordUseCase: Factory<any ChangePasswordUseCaseProtocol> {
        self { ChangePasswordUseCase(repository: self.passwordChangeRepository()) }
    }
}
