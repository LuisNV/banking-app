import Foundation

/// Backend giả cho luồng đăng ký, dùng tới khi có API thật.
/// - Email `taken@example.com` → báo email đã được dùng.
/// - Mã xác minh đúng là `123456`.
///
/// TODO: khi có API, thêm `RegistrationRemoteDataSource` + `RegistrationRepositoryImpl`
/// (giống feature Auth) rồi đổi factory trong `Container+Register.swift`.
final class MockRegistrationRepository: RegistrationRepository {
    static let validCode = "123456"
    static let takenEmail = "taken@example.com"

    private let delay: Duration

    init(delay: Duration = .milliseconds(800)) {
        self.delay = delay
    }

    func createAccount(_ info: RegistrationInfo, password: String) async throws {
        try await Task.sleep(for: delay)
        if info.email == Self.takenEmail { throw RegisterError.emailTaken }
    }

    func verifyEmail(email: String, code: String) async throws {
        try await Task.sleep(for: delay)
        guard code == Self.validCode else { throw RegisterError.invalidCode }
    }

    func resendCode(email: String) async throws {
        try await Task.sleep(for: delay / 2)
    }
}
