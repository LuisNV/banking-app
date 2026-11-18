import Foundation

protocol UploadAvatarUseCaseProtocol {
    func execute(jpegData: Data) async throws -> URL?
}

struct UploadAvatarUseCase: UploadAvatarUseCaseProtocol {
    /// Giới hạn phía app, sau khi đã thu nhỏ và nén ảnh. Chỉnh cho khớp giới hạn của server.
    static let maxMegabytes = 5
    static var maxBytes: Int { maxMegabytes * 1024 * 1024 }

    let repository: ProfileRepository

    func execute(jpegData: Data) async throws -> URL? {
        guard !jpegData.isEmpty else { throw ProfileError.invalidImage }
        guard jpegData.count <= Self.maxBytes else {
            throw ProfileError.imageTooLarge(maxMegabytes: Self.maxMegabytes)
        }
        return try await repository.uploadAvatar(jpegData: jpegData)
    }
}
