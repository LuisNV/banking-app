import Foundation

protocol RegisterUseCaseProtocol {
    /// Bước 1. Kiểm tra + chuẩn hoá thông tin, tạo phiên và lưu lại trên máy.
    func start(info: RegistrationInfo) async throws -> RegistrationSession
    /// Bước 2. Đặt mật khẩu (lần đầu: server gửi mã tới email).
    func setPassword(id: String, password: String, confirmPassword: String, biometricEnabled: Bool) async throws -> RegistrationSession
    /// Bước 3.
    func verify(id: String, code: String) async throws -> RegistrationSession
    func resendCode(id: String) async throws -> RegistrationSession
    func changeEmail(id: String, email: String) async throws -> RegistrationSession
    /// Bước 4. Tạo tài khoản, lưu token (đăng nhập luôn) và bật/tắt sinh trắc học theo lựa chọn.
    func complete(id: String) async throws -> AuthSession
    /// Phiên dở dang còn hạn trên máy (mở lại app giữa chừng). `nil` nếu không có hoặc đã hết hạn.
    func resume() async -> (saved: SavedRegistration, session: RegistrationSession)?
    /// Bỏ phiên đang lưu trên máy.
    func discard()
}

struct RegisterUseCase: RegisterUseCaseProtocol {
    static let codeLength = 6

    let repository: RegistrationRepository
    let authRepository: AuthRepository
    var now: () -> Date = Date.init

    func start(info: RegistrationInfo) async throws -> RegistrationSession {
        guard RegistrationValidator.errors(for: info, now: now()).isEmpty else { throw RegisterError.invalidInfo }
        let normalized = info.normalized
        let session = try await repository.start(normalized)
        repository.saveRegistration(SavedRegistration(id: session.id, info: normalized, createdAt: now()))
        return session
    }

    func setPassword(id: String, password: String, confirmPassword: String, biometricEnabled: Bool) async throws -> RegistrationSession {
        guard PasswordEvaluation.evaluate(password).meetsRequirements else { throw RegisterError.weakPassword }
        guard password == confirmPassword else { throw RegisterError.passwordMismatch }
        return try await clearingOnRestart {
            try await repository.initiate(
                id: id, password: password, confirmPassword: confirmPassword, biometricEnabled: biometricEnabled
            )
        }
    }

    func verify(id: String, code: String) async throws -> RegistrationSession {
        guard code.count == Self.codeLength, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw RegisterError.invalidCode(message: nil)
        }
        return try await clearingOnRestart { try await repository.verify(id: id, code: code) }
    }

    func resendCode(id: String) async throws -> RegistrationSession {
        try await clearingOnRestart { try await repository.resendCode(id: id) }
    }

    func changeEmail(id: String, email: String) async throws -> RegistrationSession {
        let normalized = RegistrationValidator.normalizedEmail(email)
        guard RegistrationValidator.isValidEmail(normalized) else { throw RegisterError.invalidInfo }
        let session = try await clearingOnRestart { try await repository.changeEmail(id: id, email: normalized) }
        if let saved = repository.savedRegistration(), saved.id == id {
            var info = saved.info
            info.email = normalized
            repository.saveRegistration(SavedRegistration(id: id, info: info, createdAt: saved.createdAt))
        }
        return session
    }

    func complete(id: String) async throws -> AuthSession {
        let result = try await clearingOnRestart { try await repository.complete(id: id) }
        try authRepository.saveSession(result.session)
        authRepository.setBiometricLoginEnabled(result.biometricEnabled)
        authRepository.setRememberedUsername(result.session.user?.username)
        repository.saveRegistration(nil)
        return result.session
    }

    func resume() async -> (saved: SavedRegistration, session: RegistrationSession)? {
        guard let saved = repository.savedRegistration() else { return nil }
        guard !saved.isExpired(now: now()) else {
            repository.saveRegistration(nil)
            return nil
        }
        do {
            let session = try await repository.status(id: saved.id)
            if session.nextStep == .completed {
                repository.saveRegistration(nil)
                return nil
            }
            return (saved, session)
        } catch let error as RegisterError where error.requiresRestart {
            repository.saveRegistration(nil)
            return nil
        } catch {
            // Lỗi mạng: không xoá phiên, lần sau mở lại vẫn thử tiếp.
            return nil
        }
    }

    func discard() {
        repository.saveRegistration(nil)
    }

    /// Phiên không còn (1005/1006) → xoá bản lưu trên máy để lần sau bắt đầu lại.
    private func clearingOnRestart<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as RegisterError where error.requiresRestart {
            repository.saveRegistration(nil)
            throw error
        }
    }
}
