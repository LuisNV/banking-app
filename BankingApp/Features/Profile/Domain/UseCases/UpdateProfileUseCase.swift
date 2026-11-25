import Foundation

protocol UpdateProfileUseCaseProtocol {
    /// - Parameter currentEmail: email hiện tại, để biết có đang đổi email không.
    func execute(_ update: ProfileUpdate, currentEmail: String?) async throws -> UserProfile
}

struct UpdateProfileUseCase: UpdateProfileUseCaseProtocol {
    let repository: ProfileRepository
    var now: () -> Date = Date.init

    func execute(_ update: ProfileUpdate, currentEmail: String?) async throws -> UserProfile {
        let errors = ProfileUpdateValidator.errors(for: update, now: now())
        guard errors.isEmpty else { throw ProfileUpdateError.invalid(errors) }

        var request = ProfileUpdateValidator.normalized(update)
        if ProfileUpdateValidator.isChangingEmail(request.email, current: currentEmail) {
            let password = request.currentPassword ?? ""
            guard !password.isEmpty else { throw ProfileUpdateError.passwordRequired }
        } else {
            // Không đổi email: không gửi email và mật khẩu.
            request.email = nil
            request.currentPassword = nil
        }
        return try await repository.updateProfile(request)
    }
}
