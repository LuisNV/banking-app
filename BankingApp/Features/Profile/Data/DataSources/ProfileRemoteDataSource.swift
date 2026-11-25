import Foundation

protocol ProfileRemoteDataSource {
    func fetchMe() async throws -> UserProfileDTO
    func updateMe(_ request: UpdateProfileRequestDTO) async throws -> UserProfileDTO
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

    func updateMe(_ request: UpdateProfileRequestDTO) async throws -> UserProfileDTO {
        try await client.request(ProfileEndpoint.updateMe(request), as: UserProfileDTO.self)
    }

    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try await client.request(ProfileEndpoint.uploadAvatar(jpegData: jpegData), as: AvatarResponseDTO.self)
    }
}

/// Backend giả cho môi trường Debug (USE_MOCK_API = YES). Upload không trả URL nên UI hiện ảnh vừa chọn.
/// Sửa hồ sơ: mật khẩu đúng là "123456"; email `taken@example.com` báo trùng (1003);
/// số `0000000000` báo trùng (1004).
final class MockProfileRemoteDataSource: ProfileRemoteDataSource {
    private var current = UserProfileDTO(
        id: "u_001",
        fullName: "Học viên Demo",
        email: "demo@tingting.vn",
        username: "demo",
        phone: "0912345678",
        birthDate: "2000-05-20",
        avatarUrl: nil,
        address: "123 Lê Lợi, Q1, TP.HCM",
        gender: "FEMALE",
        emailVerified: true
    )

    func fetchMe() async throws -> UserProfileDTO {
        try await Task.sleep(for: .milliseconds(600))
        return current
    }

    func updateMe(_ request: UpdateProfileRequestDTO) async throws -> UserProfileDTO {
        try await Task.sleep(for: .milliseconds(800))
        var email = current.email
        var verified = current.emailVerified
        if let newEmail = request.email, newEmail != current.email {
            guard let password = request.currentPassword, !password.isEmpty else {
                throw Self.error(1001, 409, "Vui lòng nhập mật khẩu hiện tại để đổi email")
            }
            guard password == MockAuthRemoteDataSource.validPassword else {
                throw Self.error(1002, 400, "Mật khẩu hiện tại không đúng")
            }
            guard newEmail != "taken@example.com" else {
                throw Self.error(1003, 409, "Email đã được sử dụng")
            }
            email = newEmail
            verified = false
        }
        guard request.phone != "0000000000" else {
            throw Self.error(1004, 409, "Số điện thoại đã được sử dụng")
        }
        current = UserProfileDTO(
            id: current.id,
            fullName: request.fullName,
            email: email,
            username: current.username,
            phone: request.phone,
            birthDate: request.dateOfBirth,
            avatarUrl: current.avatarUrl,
            address: request.address,
            gender: request.gender,
            emailVerified: verified
        )
        return current
    }

    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try await Task.sleep(for: .milliseconds(1200))
        return AvatarResponseDTO()
    }

    private static func error(_ code: Int, _ status: Int, _ message: String) -> NetworkError {
        .api(code: code, httpStatus: status, message: message, traceId: nil)
    }
}
