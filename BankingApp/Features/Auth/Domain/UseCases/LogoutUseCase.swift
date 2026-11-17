import Foundation

protocol LogoutUseCaseProtocol {
    func execute() async
}

struct LogoutUseCase: LogoutUseCaseProtocol {
    let repository: AuthRepository

    func execute() async {
        await repository.logout()
    }
}
