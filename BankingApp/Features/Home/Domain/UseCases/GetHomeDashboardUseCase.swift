import Foundation

protocol GetHomeDashboardUseCaseProtocol {
    func execute() async throws -> HomeDashboard
}

struct GetHomeDashboardUseCase: GetHomeDashboardUseCaseProtocol {
    let repository: HomeRepository

    func execute() async throws -> HomeDashboard {
        try await repository.dashboard()
    }
}
