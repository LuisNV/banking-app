import Foundation

protocol RegistrationRepository {
    /// Tạo tài khoản (chưa kích hoạt) và gửi mã xác minh tới email.
    func createAccount(_ info: RegistrationInfo, password: String) async throws
    /// Kích hoạt tài khoản bằng mã 6 số trong email.
    func verifyEmail(email: String, code: String) async throws
    func resendCode(email: String) async throws
}
