import Factory
import Foundation

extension Container {
    // MARK: Data
    var registrationRepository: Factory<any RegistrationRepository> {
        // Chưa có API đăng ký: luôn dùng backend giả. Đổi sang RegistrationRepositoryImpl khi có API.
        self { MockRegistrationRepository() }.singleton
    }

    // MARK: Domain
    var registerUseCase: Factory<any RegisterUseCaseProtocol> {
        self { RegisterUseCase(repository: self.registrationRepository()) }
    }
}
