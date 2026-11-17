import Foundation

protocol GetPublicUtilitiesUseCaseProtocol {
    func execute() async throws -> (items: [UtilityItem], support: SupportContact)
}

struct GetPublicUtilitiesUseCase: GetPublicUtilitiesUseCaseProtocol {
    let repository: UtilitiesRepository

    func execute() async throws -> (items: [UtilityItem], support: SupportContact) {
        let items = try await repository.publicUtilities()
        return (items, repository.supportContact())
    }
}
