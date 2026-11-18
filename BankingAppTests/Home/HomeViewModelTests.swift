import XCTest
@testable import BankingApp

private final class MockLogoutUseCase: LogoutUseCaseProtocol {
    func execute() async {}
}

private final class MockUploadAvatarUseCase: UploadAvatarUseCaseProtocol {
    var result: Result<URL?, Error> = .success(URL(string: "https://cdn.example.com/a.jpg"))
    private(set) var received: [Data] = []

    func execute(jpegData: Data) async throws -> URL? {
        received.append(jpegData)
        return try result.get()
    }
}

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var uploadUseCase: MockUploadAvatarUseCase!

    override func setUp() {
        super.setUp()
        uploadUseCase = MockUploadAvatarUseCase()
    }

    private func makeSUT(prepareImage: @escaping (Data) -> Data? = { $0 }) -> HomeViewModel {
        HomeViewModel(
            user: nil,
            logoutUseCase: MockLogoutUseCase(),
            uploadAvatarUseCase: uploadUseCase,
            prepareImage: prepareImage,
            onLoggedOut: {}
        )
    }

    func test_upload_success_showsNewAvatar() async {
        let sut = makeSUT(prepareImage: { _ in Data([9]) })

        await sut.uploadAvatar(from: Data([1]))

        XCTAssertEqual(uploadUseCase.received, [Data([9])])
        XCTAssertEqual(sut.avatarImageData, Data([9]))
        XCTAssertEqual(sut.avatarURL?.absoluteString, "https://cdn.example.com/a.jpg")
        XCTAssertFalse(sut.isUploadingAvatar)
        XCTAssertNil(sut.errorMessage)
    }

    func test_invalidImage_showsErrorWithoutUploading() async {
        let sut = makeSUT(prepareImage: { _ in nil })

        await sut.uploadAvatar(from: Data([1]))

        XCTAssertTrue(uploadUseCase.received.isEmpty)
        XCTAssertEqual(sut.errorMessage, ProfileError.invalidImage.errorDescription)
    }

    func test_failure_showsError_andKeepsOldAvatar() async {
        uploadUseCase.result = .failure(ProfileError.network)
        let sut = makeSUT()

        await sut.uploadAvatar(from: Data([1]))

        XCTAssertNil(sut.avatarImageData)
        XCTAssertEqual(sut.errorMessage, ProfileError.network.errorDescription)
        XCTAssertFalse(sut.isUploadingAvatar)
    }

    func test_sessionExpired_doesNotShowError() async {
        uploadUseCase.result = .failure(ProfileError.sessionExpired)
        let sut = makeSUT()

        await sut.uploadAvatar(from: Data([1]))

        XCTAssertNil(sut.errorMessage)
    }
}
