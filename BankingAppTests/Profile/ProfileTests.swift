import UIKit
import XCTest
@testable import BankingApp

// MARK: - Doubles

final class MockProfileRepository: ProfileRepository {
    var result: Result<URL?, Error> = .success(URL(string: "https://cdn.example.com/a.jpg"))
    private(set) var uploaded: [Data] = []
    var profileResult: Result<UserProfile, Error> = .failure(ProfileError.loadFailed)

    func currentProfile() async throws -> UserProfile { try profileResult.get() }

    var updateResult: Result<UserProfile, Error> = .failure(ProfileUpdateError.unknown)
    private(set) var updates: [ProfileUpdate] = []
    func updateProfile(_ update: ProfileUpdate) async throws -> UserProfile {
        updates.append(update)
        return try updateResult.get()
    }

    func uploadAvatar(jpegData: Data) async throws -> URL? {
        uploaded.append(jpegData)
        return try result.get()
    }
}

private final class StubProfileRemote: ProfileRemoteDataSource {
    var result: Result<AvatarResponseDTO, Error> = .success(AvatarResponseDTO(avatarUrl: "https://cdn.example.com/a.jpg"))
    var meResult: Result<UserProfileDTO, Error> = .failure(NetworkError.decoding)

    func fetchMe() async throws -> UserProfileDTO { try meResult.get() }
    func updateMe(_ request: UpdateProfileRequestDTO) async throws -> UserProfileDTO { try meResult.get() }

    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO {
        try result.get()
    }
}

// MARK: - Endpoint

final class ProfileEndpointTests: XCTestCase {
    func test_uploadAvatar_matchesCurlContract() {
        let data = Data([0xFF, 0xD8])
        let sut = ProfileEndpoint.uploadAvatar(jpegData: data)

        XCTAssertEqual(sut.path, "v1/users/me/avatar")
        XCTAssertEqual(sut.method.rawValue, "POST")
        XCTAssertTrue(sut.requiresAuth)
        XCTAssertNil(sut.body)
        XCTAssertEqual(sut.files, [UploadFile(fieldName: "file", fileName: "avatar.jpg", mimeType: "image/jpeg", data: data)])
    }
}

// MARK: - DTO

final class AvatarResponseDTOTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private func decode(_ json: String) throws -> AvatarResponseDTO {
        try decoder.decode(AvatarResponseDTO.self, from: Data(json.utf8))
    }

    func test_decodesString() throws {
        XCTAssertEqual(try decode(#""https://x/a.jpg""#).avatarUrl, "https://x/a.jpg")
    }

    func test_decodesCamelCaseObject() throws {
        XCTAssertEqual(try decode(#"{"id":"1","avatarUrl":"https://x/a.jpg"}"#).avatarUrl, "https://x/a.jpg")
    }

    func test_decodesSnakeCaseObject() throws {
        XCTAssertEqual(try decode(#"{"avatar_url":"https://x/a.jpg"}"#).avatarUrl, "https://x/a.jpg")
    }

    func test_decodesUrlKey() throws {
        XCTAssertEqual(try decode(#"{"url":"https://x/a.jpg"}"#).avatarUrl, "https://x/a.jpg")
    }

    func test_objectWithoutUrl_isNil() throws {
        XCTAssertNil(try decode(#"{"id":"1"}"#).avatarUrl)
    }
}

// MARK: - Use case

final class UploadAvatarUseCaseTests: XCTestCase {
    func test_validData_uploads() async throws {
        let repository = MockProfileRepository()
        let sut = UploadAvatarUseCase(repository: repository)

        let url = try await sut.execute(jpegData: Data([1, 2, 3]))

        XCTAssertEqual(url?.absoluteString, "https://cdn.example.com/a.jpg")
        XCTAssertEqual(repository.uploaded.count, 1)
    }

    func test_emptyData_throwsInvalidImage() async {
        let repository = MockProfileRepository()
        let sut = UploadAvatarUseCase(repository: repository)
        do {
            _ = try await sut.execute(jpegData: Data())
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ProfileError, .invalidImage)
        }
        XCTAssertTrue(repository.uploaded.isEmpty)
    }

    func test_tooLarge_throwsWithoutUploading() async {
        let repository = MockProfileRepository()
        let sut = UploadAvatarUseCase(repository: repository)
        do {
            _ = try await sut.execute(jpegData: Data(count: UploadAvatarUseCase.maxBytes + 1))
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ProfileError, .imageTooLarge(maxMegabytes: UploadAvatarUseCase.maxMegabytes))
        }
        XCTAssertTrue(repository.uploaded.isEmpty)
    }
}

// MARK: - Repository

final class ProfileRepositoryImplTests: XCTestCase {
    private func expectError(_ remoteError: Error, mapsTo expected: ProfileError) async {
        let remote = StubProfileRemote()
        remote.result = .failure(remoteError)
        let sut = ProfileRepositoryImpl(remote: remote)
        do {
            _ = try await sut.uploadAvatar(jpegData: Data([1]))
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ProfileError, expected)
        }
    }

    func test_success_returnsURL() async throws {
        let sut = ProfileRepositoryImpl(remote: StubProfileRemote())
        let url = try await sut.uploadAvatar(jpegData: Data([1]))
        XCTAssertEqual(url?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_successWithoutURL_returnsNil() async throws {
        let remote = StubProfileRemote()
        remote.result = .success(AvatarResponseDTO())
        let url = try await ProfileRepositoryImpl(remote: remote).uploadAvatar(jpegData: Data([1]))
        XCTAssertNil(url)
    }

    func test_errorMapping() async {
        await expectError(NetworkError.unauthorized, mapsTo: .sessionExpired)
        await expectError(NetworkError.noConnection, mapsTo: .network)
        await expectError(NetworkError.timeout, mapsTo: .network)
        await expectError(NetworkError.server(statusCode: 413), mapsTo: .imageTooLarge(maxMegabytes: UploadAvatarUseCase.maxMegabytes))
        await expectError(NetworkError.api(code: 1, httpStatus: 400, message: "Sai định dạng", traceId: nil), mapsTo: .api(message: "Sai định dạng"))
        await expectError(NetworkError.server(statusCode: 500), mapsTo: .unknown)
    }
}

// MARK: - Image processor

final class AvatarImageProcessorTests: XCTestCase {
    private func pngData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }.pngData()!
    }

    func test_largeImage_isResizedToMaxDimension() throws {
        let output = try XCTUnwrap(AvatarImageProcessor.jpegData(from: pngData(width: 3000, height: 1500)))
        let image = try XCTUnwrap(UIImage(data: output))
        XCTAssertEqual(image.size.width, AvatarImageProcessor.maxDimension)
        XCTAssertEqual(image.size.height, AvatarImageProcessor.maxDimension / 2)
    }

    func test_smallImage_isNotUpscaled() throws {
        let output = try XCTUnwrap(AvatarImageProcessor.jpegData(from: pngData(width: 200, height: 100)))
        XCTAssertEqual(UIImage(data: output)?.size, CGSize(width: 200, height: 100))
    }

    func test_invalidData_returnsNil() {
        XCTAssertNil(AvatarImageProcessor.jpegData(from: Data("not an image".utf8)))
    }
}
