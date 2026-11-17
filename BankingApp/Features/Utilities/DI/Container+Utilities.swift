import Factory
import Foundation

extension Container {
    var utilitiesRepository: Factory<any UtilitiesRepository> {
        self { UtilitiesRepositoryImpl(config: self.appConfig()) }.singleton
    }

    var getPublicUtilitiesUseCase: Factory<any GetPublicUtilitiesUseCaseProtocol> {
        self { GetPublicUtilitiesUseCase(repository: self.utilitiesRepository()) }
    }
}
