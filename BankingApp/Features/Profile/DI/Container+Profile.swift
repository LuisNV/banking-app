import Factory
import Foundation

extension Container {
    // MARK: Data
    var profileRemoteDataSource: Factory<any ProfileRemoteDataSource> {
        self { () -> any ProfileRemoteDataSource in
            if self.appConfig().useMockAPI {
                return MockProfileRemoteDataSource()
            }
            return ProfileRemoteDataSourceImpl(client: self.apiClient())
        }.singleton
    }

    var profileRepository: Factory<any ProfileRepository> {
        self { ProfileRepositoryImpl(remote: self.profileRemoteDataSource()) }.singleton
    }

    // MARK: Domain
    var uploadAvatarUseCase: Factory<any UploadAvatarUseCaseProtocol> {
        self { UploadAvatarUseCase(repository: self.profileRepository()) }
    }
}
