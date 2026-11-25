import Factory
import Foundation

extension Container {
    // MARK: Data
    var registrationRemoteDataSource: Factory<any RegistrationRemoteDataSource> {
        self { () -> any RegistrationRemoteDataSource in
            if self.appConfig().useMockAPI {
                return MockRegistrationRemoteDataSource()
            }
            return RegistrationRemoteDataSourceImpl(client: self.apiClient())
        }.singleton
    }

    var registrationRepository: Factory<any RegistrationRepository> {
        self {
            RegistrationRepositoryImpl(remote: self.registrationRemoteDataSource(), keyValueStore: self.keyValueStore())
        }.singleton
    }

    // MARK: Domain
    var registerUseCase: Factory<any RegisterUseCaseProtocol> {
        self { RegisterUseCase(repository: self.registrationRepository(), authRepository: self.authRepository()) }
    }
}
