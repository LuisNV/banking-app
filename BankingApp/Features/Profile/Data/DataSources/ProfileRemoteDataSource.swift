import Foundation

protocol ProfileRemoteDataSource {
    func fetchMe() async throws -> UserProfileDTO
    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO
}

final class ProfileRemoteDataSourceImpl: ProfileRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchMe() async throws -> UserProfileDTO {
        try await client.request(ProfileEndpoint.me, as: UserProfileDTO.self)
    }

    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try await client.request(ProfileEndpoint.uploadAvatar(jpegData: jpegData), as: AvatarResponseDTO.self)
    }
}

/// Backend giả cho môi trường Debug (USE_MOCK_API = YES). Không trả URL nên UI hiện ảnh vừa chọn.
final class MockProfileRemoteDataSource: ProfileRemoteDataSource {
    func fetchMe() async throws -> UserProfileDTO {
        try await Task.sleep(for: .milliseconds(600))
        return UserProfileDTO(
            id: "u_001",
            fullName: "Học viên Demo",
            email: "demo@tingting.vn",
            username: "demo",
            phone: "0912345678",
            birthDate: "2000-05-20",
            avatarUrl: nil
        )
    }

    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try await Task.sleep(for: .milliseconds(1200))
        return AvatarResponseDTO()
    }
}
