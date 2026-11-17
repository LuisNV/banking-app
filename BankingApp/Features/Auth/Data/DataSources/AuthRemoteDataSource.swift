import Foundation

protocol AuthRemoteDataSource {
    func login(_ request: LoginRequestDTO) async throws -> AuthResponseDTO
    func refresh(_ request: RefreshTokenRequestDTO) async throws -> AuthResponseDTO
    func logout() async throws
}

final class AuthRemoteDataSourceImpl: AuthRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func login(_ request: LoginRequestDTO) async throws -> AuthResponseDTO {
        try await client.request(AuthEndpoint.login(request), as: AuthResponseDTO.self)
    }

    func refresh(_ request: RefreshTokenRequestDTO) async throws -> AuthResponseDTO {
        try await client.request(AuthEndpoint.refresh(request), as: AuthResponseDTO.self)
    }

    func logout() async throws {
        _ = try await client.request(AuthEndpoint.logout, as: EmptyResponseDTO.self)
    }
}

/// Backend giả cho môi trường Debug (USE_MOCK_API = YES).
/// Chấp nhận mọi tài khoản, mật khẩu đúng là "123456".
final class MockAuthRemoteDataSource: AuthRemoteDataSource {
    static let validPassword = "123456"

    func login(_ request: LoginRequestDTO) async throws -> AuthResponseDTO {
        try await Task.sleep(for: .milliseconds(900))
        guard request.password == Self.validPassword else {
            throw NetworkError.unauthorized
        }
        return Self.response(username: request.email)
    }

    func refresh(_ request: RefreshTokenRequestDTO) async throws -> AuthResponseDTO {
        try await Task.sleep(for: .milliseconds(500))
        return Self.response(username: "demo")
    }

    func logout() async throws {}

    private static func response(username: String) -> AuthResponseDTO {
        AuthResponseDTO(
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiresIn: 900,
            tokenType: "Bearer",
            user: UserDTO(id: "u_001", fullName: "Học viên Demo", username: username)
        )
    }
}
