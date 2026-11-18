import Foundation

protocol ProfileRemoteDataSource {
    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO
}

final class ProfileRemoteDataSourceImpl: ProfileRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try await client.request(ProfileEndpoint.uploadAvatar(jpegData: jpegData), as: AvatarResponseDTO.self)
    }
}

/// Backend giả cho môi trường Debug (USE_MOCK_API = YES). Không trả URL nên UI hiện ảnh vừa chọn.
final class MockProfileRemoteDataSource: ProfileRemoteDataSource {
    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try await Task.sleep(for: .milliseconds(1200))
        return AvatarResponseDTO()
    }
}
