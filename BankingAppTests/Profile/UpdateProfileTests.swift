import XCTest
@testable import BankingApp

// MARK: - Helpers

private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.current.date(from: components)!
}

private let today = makeDate(2026, 11, 25)

private func makeProfile(email: String? = "user@example.com") -> UserProfile {
    UserProfile(
        id: "1", fullName: "Nguyen Van A", email: email, username: nil,
        phone: "0901234567", birthDate: makeDate(1995, 5, 20), avatarURL: nil,
        address: "123 Le Loi, Q1, HCM", gender: .male, isEmailVerified: true
    )
}

private func makeUpdate(
    fullName: String = "Nguyen Van A",
    phone: String = "0901234567",
    address: String = "123 Le Loi, Q1, HCM",
    birthDate: Date? = makeDate(1995, 5, 20),
    email: String? = nil,
    password: String? = nil
) -> ProfileUpdate {
    ProfileUpdate(
        fullName: fullName, phone: phone, address: address, gender: .male,
        birthDate: birthDate, email: email, currentPassword: password
    )
}

private final class RecordingRemote: ProfileRemoteDataSource {
    var result: Result<UserProfileDTO, Error> = .success(UserProfileDTO(
        id: "1", fullName: "Nguyen Van A", email: "user@example.com", username: nil,
        phone: "0901234567", birthDate: "1995-05-20", avatarUrl: nil
    ))
    private(set) var requests: [UpdateProfileRequestDTO] = []

    func fetchMe() async throws -> UserProfileDTO { try result.get() }
    func updateMe(_ request: UpdateProfileRequestDTO) async throws -> UserProfileDTO {
        requests.append(request)
        return try result.get()
    }
    func uploadAvatar(jpegData: Data) async throws -> AvatarResponseDTO { AvatarResponseDTO() }
}

// MARK: - Endpoint & DTO

final class UpdateProfileEndpointTests: XCTestCase {
    func test_endpoint_matchesCurl() {
        let sut = ProfileEndpoint.updateMe(UpdateProfileRequestDTO(makeUpdate()))
        XCTAssertEqual(sut.path, "v1/users/me")
        XCTAssertEqual(sut.method.rawValue, "PUT")
        XCTAssertTrue(sut.requiresAuth)
        XCTAssertNotNil(sut.body)
        XCTAssertNil(sut.files)
    }

    private func json(_ dto: UpdateProfileRequestDTO) throws -> [String: String] {
        let data = try JSONEncoder().encode(dto)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    func test_body_keepEmail_sendsFiveFieldsOnly() throws {
        let body = try json(UpdateProfileRequestDTO(makeUpdate()))
        XCTAssertEqual(body, [
            "fullName": "Nguyen Van A",
            "phone": "0901234567",
            "address": "123 Le Loi, Q1, HCM",
            "gender": "MALE",
            "dateOfBirth": "1995-05-20",
        ])
    }

    func test_body_changeEmail_includesEmailAndPassword() throws {
        let body = try json(UpdateProfileRequestDTO(makeUpdate(email: "new@example.com", password: "123456")))
        XCTAssertEqual(body["email"], "new@example.com")
        XCTAssertEqual(body["currentPassword"], "123456")
    }
}

// MARK: - Validator

final class ProfileUpdateValidatorTests: XCTestCase {
    func test_valid() {
        XCTAssertTrue(ProfileUpdateValidator.errors(for: makeUpdate(), now: today).isEmpty)
    }

    func test_requiredFields_blankOrSpaces() {
        let errors = ProfileUpdateValidator.errors(for: makeUpdate(fullName: "  ", phone: "", address: " \n"), now: today)
        XCTAssertNotNil(errors[.fullName])
        XCTAssertNotNil(errors[.phone])
        XCTAssertNotNil(errors[.address])
    }

    func test_maxLengths_countAfterTrimming() {
        XCTAssertNil(ProfileUpdateValidator.errors(
            for: makeUpdate(fullName: " " + String(repeating: "a", count: 150) + " "), now: today)[.fullName])
        XCTAssertNotNil(ProfileUpdateValidator.errors(
            for: makeUpdate(fullName: String(repeating: "a", count: 151)), now: today)[.fullName])
        XCTAssertNotNil(ProfileUpdateValidator.errors(
            for: makeUpdate(phone: String(repeating: "1", count: 31)), now: today)[.phone])
        XCTAssertNotNil(ProfileUpdateValidator.errors(
            for: makeUpdate(address: String(repeating: "x", count: 501)), now: today)[.address])
    }

    func test_birthDate_todayOk_futureRejected() {
        XCTAssertNil(ProfileUpdateValidator.errors(for: makeUpdate(birthDate: today), now: today)[.birthDate])
        XCTAssertNotNil(ProfileUpdateValidator.errors(for: makeUpdate(birthDate: makeDate(2026, 11, 26)), now: today)[.birthDate])
        XCTAssertNil(ProfileUpdateValidator.errors(for: makeUpdate(birthDate: nil), now: today)[.birthDate])
    }

    func test_email_rules() {
        XCTAssertNotNil(ProfileUpdateValidator.errors(for: makeUpdate(email: "   "), now: today)[.email])
        XCTAssertNotNil(ProfileUpdateValidator.errors(for: makeUpdate(email: "abc"), now: today)[.email])
        let long = String(repeating: "a", count: 250) + "@b.co"
        XCTAssertNotNil(ProfileUpdateValidator.errors(for: makeUpdate(email: long), now: today)[.email])
        XCTAssertNil(ProfileUpdateValidator.errors(for: makeUpdate(email: " New@Example.com "), now: today)[.email])
    }

    func test_isChangingEmail_ignoresCaseAndSpaces() {
        XCTAssertFalse(ProfileUpdateValidator.isChangingEmail(" USER@example.com ", current: "user@example.com"))
        XCTAssertTrue(ProfileUpdateValidator.isChangingEmail("new@example.com", current: "user@example.com"))
        XCTAssertFalse(ProfileUpdateValidator.isChangingEmail(nil, current: "user@example.com"))
    }
}

// MARK: - Use case & repository

final class UpdateProfileUseCaseTests: XCTestCase {
    func test_sameEmail_dropsEmailAndPassword_andTrims() async throws {
        let repository = MockProfileRepository()
        repository.updateResult = .success(makeProfile())
        let sut = UpdateProfileUseCase(repository: repository, now: { today })

        _ = try await sut.execute(
            makeUpdate(fullName: "  Nguyen Van B ", phone: " 0909 ", address: " HN ", email: "USER@example.com", password: "x"),
            currentEmail: "user@example.com"
        )

        let sent = try XCTUnwrap(repository.updates.first)
        XCTAssertEqual(sent.fullName, "Nguyen Van B")
        XCTAssertEqual(sent.phone, "0909")
        XCTAssertEqual(sent.address, "HN")
        XCTAssertNil(sent.email)
        XCTAssertNil(sent.currentPassword)
    }

    func test_changeEmail_withoutPassword_throws1001_withoutCallingServer() async {
        let repository = MockProfileRepository()
        let sut = UpdateProfileUseCase(repository: repository, now: { today })
        do {
            _ = try await sut.execute(makeUpdate(email: "new@example.com"), currentEmail: "user@example.com")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ProfileUpdateError, .passwordRequired)
        }
        XCTAssertTrue(repository.updates.isEmpty)
    }

    func test_changeEmail_sendsLowercasedEmailAndPassword() async throws {
        let repository = MockProfileRepository()
        repository.updateResult = .success(makeProfile(email: "new@example.com"))
        let sut = UpdateProfileUseCase(repository: repository, now: { today })

        _ = try await sut.execute(makeUpdate(email: " New@Example.com ", password: "123456"), currentEmail: "user@example.com")

        XCTAssertEqual(repository.updates.first?.email, "new@example.com")
        XCTAssertEqual(repository.updates.first?.currentPassword, "123456")
    }

    func test_invalid_throwsWithoutCallingServer() async {
        let repository = MockProfileRepository()
        let sut = UpdateProfileUseCase(repository: repository, now: { today })
        do {
            _ = try await sut.execute(makeUpdate(fullName: ""), currentEmail: nil)
            XCTFail("Expected error")
        } catch let ProfileUpdateError.invalid(errors) {
            XCTAssertNotNil(errors[.fullName])
        } catch {
            XCTFail("Unexpected \(error)")
        }
        XCTAssertTrue(repository.updates.isEmpty)
    }

    func test_repository_mapsServerCodes() {
        func api(_ code: Int, _ status: Int, _ message: String = "msg") -> NetworkError {
            .api(code: code, httpStatus: status, message: message, traceId: nil)
        }
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(1001, 409)), .passwordRequired)
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(1002, 400)), .wrongPassword)
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(1003, 409)), .emailTaken)
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(1004, 409)), .phoneTaken)
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(401, 401)), .sessionExpired)
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(404, 404)), .accountNotFound)
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(api(400, 400, "fullName không được để trống")),
                       .api(message: "fullName không được để trống"))
        XCTAssertEqual(ProfileRepositoryImpl.mapUpdate(NetworkError.noConnection), .network)
    }

    func test_repository_sendsDTO_andReturnsNewProfile() async throws {
        let remote = RecordingRemote()
        let sut = ProfileRepositoryImpl(remote: remote)

        let profile = try await sut.updateProfile(makeUpdate())

        XCTAssertEqual(remote.requests.first?.dateOfBirth, "1995-05-20")
        XCTAssertEqual(remote.requests.first?.gender, "MALE")
        XCTAssertEqual(profile.fullName, "Nguyen Van A")
    }
}

// MARK: - ViewModel

private final class StubUpdateUseCase: UpdateProfileUseCaseProtocol {
    var results: [Result<UserProfile, Error>] = []
    private(set) var calls: [ProfileUpdate] = []

    func execute(_ update: ProfileUpdate, currentEmail: String?) async throws -> UserProfile {
        calls.append(update)
        return try (results.isEmpty ? .success(makeProfile()) : results.removeFirst()).get()
    }
}

@MainActor
final class EditProfileViewModelTests: XCTestCase {
    private var useCase: StubUpdateUseCase!
    private var saved: [UserProfile] = []
    private var accountGone = false

    override func setUp() {
        super.setUp()
        useCase = StubUpdateUseCase()
        saved = []
        accountGone = false
    }

    private func makeSUT(profile: UserProfile = makeProfile()) -> EditProfileViewModel {
        EditProfileViewModel(
            profile: profile,
            updateUseCase: useCase,
            now: { today },
            onSaved: { [unowned self] in self.saved.append($0) },
            onAccountGone: { [unowned self] in self.accountGone = true }
        )
    }

    func test_prefillsFromProfile_andHasNoChanges() {
        let sut = makeSUT()
        XCTAssertEqual(sut.fullName, "Nguyen Van A")
        XCTAssertEqual(sut.email, "user@example.com")
        XCTAssertFalse(sut.hasChanges)
        XCTAssertFalse(sut.canSave)
    }

    func test_saveWithoutEmailChange_submitsDirectly() async {
        let sut = makeSUT()
        sut.address = "456 Nguyen Hue"

        await sut.save()

        XCTAssertFalse(sut.isShowingPasswordSheet)
        XCTAssertEqual(useCase.calls.count, 1)
        XCTAssertNil(useCase.calls.first?.currentPassword)
        XCTAssertEqual(saved.count, 1)
        XCTAssertTrue(sut.didSave)
    }

    func test_emailChange_opensPasswordSheet_thenSubmitsWithPassword() async {
        let sut = makeSUT()
        sut.email = "new@example.com"
        XCTAssertTrue(sut.isChangingEmail)

        await sut.save()
        XCTAssertTrue(sut.isShowingPasswordSheet)
        XCTAssertTrue(useCase.calls.isEmpty)

        sut.currentPassword = "123456"
        await sut.confirmPassword()

        XCTAssertEqual(useCase.calls.first?.currentPassword, "123456")
        XCTAssertEqual(useCase.calls.first?.email, "new@example.com")
        XCTAssertFalse(sut.isShowingPasswordSheet)
        XCTAssertTrue(sut.didSave)
    }

    func test_emptyPassword_showsErrorInSheet() async {
        let sut = makeSUT()
        sut.email = "new@example.com"
        await sut.save()

        await sut.confirmPassword()

        XCTAssertEqual(sut.passwordError, ProfileUpdateError.passwordRequired.errorDescription)
        XCTAssertTrue(useCase.calls.isEmpty)
    }

    func test_wrongPassword_keepsSheetOpen() async {
        useCase.results = [.failure(ProfileUpdateError.wrongPassword)]
        let sut = makeSUT()
        sut.email = "new@example.com"
        await sut.save()
        sut.currentPassword = "bad"

        await sut.confirmPassword()

        XCTAssertTrue(sut.isShowingPasswordSheet)
        XCTAssertEqual(sut.passwordError, ProfileUpdateError.wrongPassword.errorDescription)
        XCTAssertEqual(sut.currentPassword, "")
        XCTAssertFalse(sut.didSave)
    }

    func test_emailTaken_closesSheet_andMarksEmailField() async {
        useCase.results = [.failure(ProfileUpdateError.emailTaken)]
        let sut = makeSUT()
        sut.email = "taken@example.com"
        await sut.save()
        sut.currentPassword = "123456"

        await sut.confirmPassword()

        XCTAssertFalse(sut.isShowingPasswordSheet)
        XCTAssertEqual(sut.error(for: .email), ProfileUpdateError.emailTaken.errorDescription)

        sut.didEdit(.email)
        sut.email = "other@example.com"
        XCTAssertNil(sut.error(for: .email))
    }

    func test_phoneTaken_marksPhoneField() async {
        useCase.results = [.failure(ProfileUpdateError.phoneTaken)]
        let sut = makeSUT()
        sut.phone = "0911111111"

        await sut.save()

        XCTAssertEqual(sut.error(for: .phone), ProfileUpdateError.phoneTaken.errorDescription)
        XCTAssertFalse(sut.didSave)
    }

    func test_passwordRequiredFromServer_opensSheet() async {
        useCase.results = [.failure(ProfileUpdateError.passwordRequired)]
        let sut = makeSUT()
        sut.address = "Khác"

        await sut.save()

        XCTAssertTrue(sut.isShowingPasswordSheet)
        XCTAssertNotNil(sut.passwordError)
    }

    func test_accountNotFound_callsAccountGone() async {
        useCase.results = [.failure(ProfileUpdateError.accountNotFound)]
        let sut = makeSUT()
        sut.address = "Khác"

        await sut.save()

        XCTAssertTrue(accountGone)
    }

    func test_validationErrors_blockSave_andShowAfterTrying() async {
        let sut = makeSUT()
        sut.fullName = ""
        XCTAssertNil(sut.error(for: .fullName), "Chưa bấm Lưu thì chưa báo trống")

        await sut.save()

        XCTAssertNotNil(sut.error(for: .fullName))
        XCTAssertTrue(useCase.calls.isEmpty)
    }

    func test_networkError_showsAlert() async {
        useCase.results = [.failure(ProfileUpdateError.network)]
        let sut = makeSUT()
        sut.address = "Khác"

        await sut.save()

        XCTAssertEqual(sut.alertMessage, ProfileUpdateError.network.errorDescription)
    }
}
