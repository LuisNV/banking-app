import Foundation

protocol LoginUseCaseProtocol {
    func execute(username: String, password: String, rememberUsername: Bool) async throws -> AuthSession
}

struct LoginUseCase: LoginUseCaseProtocol {
    static let minimumPasswordLength = 6

    let repository: AuthRepository

    func execute(username: String, password: String, rememberUsername: Bool) async throws -> AuthSession {
        let username = Self.normalizedIdentifier(username)
        guard !username.isEmpty else { throw AuthError.emptyUsername }
        guard password.count >= Self.minimumPasswordLength else { throw AuthError.invalidPassword }

        let session = try await repository.login(username: username, password: password)
        repository.setRememberedUsername(rememberUsername ? username : nil)
        return session
    }

    /// `identifier` là email hoặc số điện thoại:
    /// - có "@": bỏ khoảng trắng hai đầu, chữ thường;
    /// - toàn chữ số (cho phép khoảng trắng, dấu chấm, gạch, "+84"): "091 234 5678" → "0912345678".
    /// - còn lại: chỉ bỏ khoảng trắng hai đầu.
    static func normalizedIdentifier(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") { return trimmed.lowercased() }
        let phoneCharacters = CharacterSet(charactersIn: "+0123456789 .-()")
        let isPhone = !trimmed.isEmpty
            && trimmed.unicodeScalars.allSatisfy { phoneCharacters.contains($0) }
            && trimmed.contains(where: \.isNumber)
        return isPhone ? RegistrationValidator.normalizedPhone(trimmed) : trimmed
    }
}
