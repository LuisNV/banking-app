import Factory
import Foundation

extension Container {
    // MARK: Data
    var homeRepository: Factory<any HomeRepository> {
        // Chưa có API Trang chủ: dùng dữ liệu mẫu.
        self { MockHomeRepository() }.singleton
    }

    // MARK: Domain
    var getHomeDashboardUseCase: Factory<any GetHomeDashboardUseCaseProtocol> {
        self { GetHomeDashboardUseCase(repository: self.homeRepository()) }
    }

    // MARK: Services
    var pronunciationService: Factory<any PronunciationServiceProtocol> {
        self { PronunciationService() }.singleton
    }
}
