import Foundation

protocol LoginUseCaseProtocol {
    func execute(username: String, password: String, rememberUsername: Bool) async throws -> AuthSession
}

struct LoginUseCase: LoginUseCaseProtocol {
    static let minimumPasswordLength = 6

    let repository: AuthRepository

    func execute(username: String, password: String, rememberUsername: Bool) async throws -> AuthSession {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { throw AuthError.emptyUsername }
        guard password.count >= Self.minimumPasswordLength else { throw AuthError.invalidPassword }

        let session = try await repository.login(username: username, password: password)
        repository.setRememberedUsername(rememberUsername ? username : nil)
        return session
    }
}
