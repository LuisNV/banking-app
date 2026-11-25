import Foundation

protocol GetMyProfileUseCaseProtocol {
    func execute() async throws -> UserProfile
}

struct GetMyProfileUseCase: GetMyProfileUseCaseProtocol {
    let repository: ProfileRepository

    func execute() async throws -> UserProfile {
        try await repository.currentProfile()
    }
}
