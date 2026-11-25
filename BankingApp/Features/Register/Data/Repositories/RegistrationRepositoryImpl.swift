import Foundation

final class RegistrationRepositoryImpl: RegistrationRepository {
    private enum Key {
        static let savedRegistration = "register.saved_registration"
    }

    private let remote: RegistrationRemoteDataSource
    private let keyValueStore: KeyValueStore

    init(remote: RegistrationRemoteDataSource, keyValueStore: KeyValueStore) {
        self.remote = remote
        self.keyValueStore = keyValueStore
    }

    func start(_ info: RegistrationInfo) async throws -> RegistrationSession {
        let request = RegistrationStartRequestDTO(
            fullName: info.fullName,
            email: info.email,
            phone: info.phone,
            dateOfBirth: Self.formatDay(info.birthDate)
        )
        return try await mapping { try await remote.start(request).toDomain(fallbackId: nil) }
    }

    func initiate(id: String, password: String, confirmPassword: String, biometricEnabled: Bool) async throws -> RegistrationSession {
        let request = RegistrationInitiateRequestDTO(
            password: password, confirmPassword: confirmPassword, biometricEnabled: biometricEnabled
        )
        return try await mapping { try await remote.initiate(id: id, request).toDomain(fallbackId: id) }
    }

    func verify(id: String, code: String) async throws -> RegistrationSession {
        try await mapping { try await remote.verify(id: id, RegistrationVerifyRequestDTO(code: code)).toDomain(fallbackId: id) }
    }

    func resendCode(id: String) async throws -> RegistrationSession {
        try await mapping { try await remote.resendOTP(id: id).toDomain(fallbackId: id) }
    }

    func changeEmail(id: String, email: String) async throws -> RegistrationSession {
        try await mapping {
            var session = try await remote.changeEmail(id: id, RegistrationEmailRequestDTO(email: email)).toDomain(fallbackId: id)
            session.email = session.email ?? email
            return session
        }
    }

    func complete(id: String) async throws -> RegistrationResult {
        try await mapping { try await remote.complete(id: id).toDomain() }
    }

    func status(id: String) async throws -> RegistrationSession {
        try await mapping { try await remote.status(id: id).toDomain(fallbackId: id) }
    }

    // MARK: Lưu trên máy

    func savedRegistration() -> SavedRegistration? {
        guard let json = keyValueStore.string(forKey: Key.savedRegistration),
              let stored = try? JSONDecoder().decode(StoredRegistration.self, from: Data(json.utf8))
        else { return nil }
        return SavedRegistration(
            id: stored.id,
            info: RegistrationInfo(
                fullName: stored.fullName,
                email: stored.email,
                phone: stored.phone,
                birthDate: stored.birthDate
            ),
            createdAt: stored.createdAt
        )
    }

    func saveRegistration(_ registration: SavedRegistration?) {
        guard let registration else {
            keyValueStore.removeObject(forKey: Key.savedRegistration)
            return
        }
        let stored = StoredRegistration(
            id: registration.id,
            fullName: registration.info.fullName,
            email: registration.info.email,
            phone: registration.info.phone,
            birthDate: registration.info.birthDate,
            createdAt: registration.createdAt
        )
        guard let data = try? JSONEncoder().encode(stored), let json = String(data: data, encoding: .utf8) else { return }
        keyValueStore.set(json, forKey: Key.savedRegistration)
    }

    // MARK: Lỗi

    private func mapping<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw Self.map(error)
        }
    }

    static func map(_ error: Error) -> RegisterError {
        if let registerError = error as? RegisterError { return registerError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        case .api(let code, let httpStatus, let message, _):
            switch code {
            case 1003: return .emailTaken
            case 1004: return .phoneTaken
            case 1005: return .sessionNotFound
            case 1006: return .sessionExpired
            case 1007: return .wrongStep
            case 1008: return .passwordMismatch
            case 1009: return .weakPassword
            case 1010: return .invalidCode(message: message)
            case 1011: return .codeExpired
            case 1012: return .tooManyAttempts
            case 1013: return .resendTooSoon(message: message)
            case 1014: return .sendLimitReached
            default: break
            }
            if httpStatus == 502 || code == 502 { return .emailDeliveryFailed }
            if httpStatus == 503 || code == 503 { return .emailServiceUnavailable }
            return message.isEmpty ? .unknown : .api(message: message)
        case .server(let statusCode) where statusCode == 502:
            return .emailDeliveryFailed
        case .server(let statusCode) where statusCode == 503:
            return .emailServiceUnavailable
        case .noConnection, .timeout: return .network
        case .unauthorized, .server, .decoding, .unknown: return .unknown
        }
    }

    static func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct StoredRegistration: Codable {
    let id: String
    let fullName: String
    let email: String
    let phone: String
    let birthDate: Date
    let createdAt: Date
}
