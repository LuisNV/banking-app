import XCTest
@testable import BankingApp

private func decodeEnvelope(_ json: String) throws -> UserProfileDTO {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let envelope = try decoder.decode(APIResponse<UserProfileDTO>.self, from: Data(json.utf8))
    return try XCTUnwrap(envelope.data)
}

private final class MeRemote: ProfileRemoteDataSource {
    var meResult: Result<UserProfileDTO, Error>
    init(_ result: Result<UserProfileDTO, Error>) { meResult = result }
    func fetchMe() async throws -> UserProfileDTO { try meResult.get() }
    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO { AvatarResponseDTO() }
}

final class MyProfileTests: XCTestCase {
    func test_meEndpoint_matchesCurl() {
        let sut = ProfileEndpoint.me
        XCTAssertEqual(sut.path, "v1/auth/me")
        XCTAssertEqual(sut.method.rawValue, "GET")
        XCTAssertTrue(sut.requiresAuth)
        XCTAssertNil(sut.body)
        XCTAssertNil(sut.files)
    }

    /// Đúng response mẫu của backend.
    func test_decode_backendSample() throws {
        let dto = try decodeEnvelope("""
        {
          "code": 0,
          "httpStatus": 200,
          "message": "Thành công",
          "data": {
            "id": 1,
            "fullName": "Nguyen Van A",
            "email": "user@example.com",
            "phone": "0901234567",
            "address": "123 Le Loi, Q1, HCM",
            "gender": "MALE",
            "dateOfBirth": "1995-05-20",
            "avatarUrl": "https://res.cloudinary.com/demo/image/upload/a.jpg",
            "emailVerified": true
          },
          "traceId": "abc"
        }
        """)
        let profile = dto.toDomain()

        XCTAssertEqual(profile.id, "1")
        XCTAssertEqual(profile.fullName, "Nguyen Van A")
        XCTAssertEqual(profile.email, "user@example.com")
        XCTAssertNil(profile.username)
        XCTAssertEqual(profile.phone, "0901234567")
        XCTAssertEqual(profile.address, "123 Le Loi, Q1, HCM")
        XCTAssertEqual(profile.gender, .male)
        XCTAssertEqual(profile.gender?.title, "Nam")
        XCTAssertEqual(profile.isEmailVerified, true)
        XCTAssertEqual(profile.avatarURL?.absoluteString, "https://res.cloudinary.com/demo/image/upload/a.jpg")
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: try XCTUnwrap(profile.birthDate))
        XCTAssertEqual([parts.year, parts.month, parts.day], [1995, 5, 20])
    }

    func test_gender_mapping() {
        XCTAssertEqual(UserProfile.Gender(apiValue: "FEMALE"), .female)
        XCTAssertEqual(UserProfile.Gender(apiValue: "other"), .other)
        XCTAssertNil(UserProfile.Gender(apiValue: "UNKNOWN"))
    }

    func test_decode_camelCase() throws {
        let dto = try decodeEnvelope("""
        {"code":0,"httpStatus":200,"message":"OK","traceId":"t","data":{
          "id":"u_001","fullName":"Nguyễn Minh Anh","email":"user@example.com","username":"minhanh",
          "phone":"0912345678","birthDate":"2000-05-20","avatarUrl":"https://cdn.example.com/a.jpg"}}
        """)
        let profile = dto.toDomain()

        XCTAssertEqual(profile.id, "u_001")
        XCTAssertEqual(profile.fullName, "Nguyễn Minh Anh")
        XCTAssertEqual(profile.email, "user@example.com")
        XCTAssertEqual(profile.username, "minhanh")
        XCTAssertEqual(profile.phone, "0912345678")
        XCTAssertEqual(profile.avatarURL?.absoluteString, "https://cdn.example.com/a.jpg")
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: try XCTUnwrap(profile.birthDate))
        XCTAssertEqual([parts.year, parts.month, parts.day], [2000, 5, 20])
    }

    func test_decode_snakeCase_numericId_andAlternateNames() throws {
        let dto = try decodeEnvelope("""
        {"code":0,"httpStatus":200,"message":"OK","data":{
          "id":42,"full_name":"Trần An","email":"an@example.com",
          "phone_number":"0987","date_of_birth":"1999-01-02T00:00:00Z","avatar":""}}
        """)
        let profile = dto.toDomain()

        XCTAssertEqual(profile.id, "42")
        XCTAssertEqual(profile.fullName, "Trần An")
        XCTAssertEqual(profile.phone, "0987")
        XCTAssertNotNil(profile.birthDate)
        XCTAssertNil(profile.avatarURL)
        XCTAssertNil(profile.username)
    }

    func test_decode_onlyIdAndEmail_usesEmailAsName() throws {
        let dto = try decodeEnvelope("""
        {"code":0,"httpStatus":200,"message":"OK","data":{"id":"1","email":"user@example.com"}}
        """)
        XCTAssertEqual(dto.toDomain().fullName, "user@example.com")
    }

    func test_repository_mapsErrors() async {
        let expired = ProfileRepositoryImpl(remote: MeRemote(.failure(NetworkError.unauthorized)))
        do {
            _ = try await expired.currentProfile()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ProfileError, .sessionExpired)
        }

        let broken = ProfileRepositoryImpl(remote: MeRemote(.failure(NetworkError.decoding)))
        do {
            _ = try await broken.currentProfile()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ProfileError, .loadFailed)
        }
    }
}
