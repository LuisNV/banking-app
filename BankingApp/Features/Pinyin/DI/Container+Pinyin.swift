import Factory
import Foundation

extension Container {
    var pinyinRepository: Factory<any PinyinRepository> {
        self { () -> any PinyinRepository in
            if self.appConfig().useMockAPI {
                return MockPinyinRepository()
            }
            return PinyinRepositoryImpl(client: self.apiClient(), apiBaseURL: self.appConfig().baseURL)
        }.singleton
    }
}
