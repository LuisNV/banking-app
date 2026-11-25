import Foundation

final class ProfileRepositoryImpl: ProfileRepository {
    private let remote: ProfileRemoteDataSource

    init(remote: ProfileRemoteDataSource) {
        self.remote = remote
    }

    func currentProfile() async throws -> UserProfile {
        do {
            return try await remote.fetchMe().toDomain()
        } catch {
            let mapped = Self.map(error)
            throw mapped == .unknown ? ProfileError.loadFailed : mapped
        }
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> UserProfile {
        do {
            return try await remote.updateMe(UpdateProfileRequestDTO(update)).toDomain()
        } catch {
            throw Self.mapUpdate(error)
        }
    }

    func uploadAvatar(jpegData: Data) async throws -> URL? {
        do {
            let dto = try await remote.uploadAvatar(jpegData: jpegData)
            return dto.avatarUrl.flatMap(URL.init(string:))
        } catch {
            throw Self.map(error)
        }
    }

    /// Mã lỗi theo hợp đồng `PUT v1/users/me`.
    static func mapUpdate(_ error: Error) -> ProfileUpdateError {
        if let updateError = error as? ProfileUpdateError { return updateError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        case .unauthorized: return .sessionExpired
        case .api(let code, let httpStatus, let message, _):
            switch code {
            case 1001: return .passwordRequired
            case 1002: return .wrongPassword
            case 1003: return .emailTaken
            case 1004: return .phoneTaken
            default: break
            }
            if httpStatus == 401 { return .sessionExpired }
            if httpStatus == 404 { return .accountNotFound }
            return message.isEmpty ? .unknown : .api(message: message)
        case .server(let statusCode) where statusCode == 404:
            return .accountNotFound
        case .noConnection, .timeout: return .network
        case .server, .decoding, .unknown: return .unknown
        }
    }

    private static func map(_ error: Error) -> ProfileError {
        if let profileError = error as? ProfileError { return profileError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        // Đến được đây nghĩa là AuthInterceptor đã thử refresh mà không được.
        case .unauthorized: return .sessionExpired
        case .api(_, let httpStatus, let message, _):
            if httpStatus == 401 { return .sessionExpired }
            if httpStatus == 413 { return .imageTooLarge(maxMegabytes: UploadAvatarUseCase.maxMegabytes) }
            return message.isEmpty ? .unknown : .api(message: message)
        case .server(let statusCode) where statusCode == 413:
            return .imageTooLarge(maxMegabytes: UploadAvatarUseCase.maxMegabytes)
        case .noConnection, .timeout: return .network
        case .server, .decoding, .unknown: return .unknown
        }
    }
}
