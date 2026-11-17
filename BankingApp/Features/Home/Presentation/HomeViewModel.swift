import Factory
import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    let user: User?
    private(set) var isLoggingOut = false

    private let logoutUseCase: LogoutUseCaseProtocol
    private let onLoggedOut: () -> Void

    init(
        user: User?,
        logoutUseCase: LogoutUseCaseProtocol = Container.shared.logoutUseCase(),
        onLoggedOut: @escaping () -> Void
    ) {
        self.user = user
        self.logoutUseCase = logoutUseCase
        self.onLoggedOut = onLoggedOut
    }

    func logout() async {
        isLoggingOut = true
        await logoutUseCase.execute()
        isLoggingOut = false
        onLoggedOut()
    }
}
