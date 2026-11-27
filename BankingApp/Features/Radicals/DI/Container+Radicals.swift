import Factory
import Foundation

extension Container {
    var radicalsRepository: Factory<any RadicalsRepository> {
        self { () -> any RadicalsRepository in
            if self.appConfig().useMockAPI {
                return MockRadicalsRepository()
            }
            return RadicalsRepositoryImpl(client: self.apiClient())
        }.singleton
    }
}
