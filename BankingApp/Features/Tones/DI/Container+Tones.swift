import Factory
import Foundation

extension Container {
    var tonesRepository: Factory<any TonesRepository> {
        self { () -> any TonesRepository in
            if self.appConfig().useMockAPI {
                return MockTonesRepository()
            }
            return TonesRepositoryImpl(client: self.apiClient(), apiBaseURL: self.appConfig().baseURL)
        }.singleton
    }
}
