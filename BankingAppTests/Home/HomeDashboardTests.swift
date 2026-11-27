import XCTest
@testable import BankingApp

private final class NoopLogoutUseCase: LogoutUseCaseProtocol {
    func execute() async {}
}

private final class NoopUploadAvatarUseCase: UploadAvatarUseCaseProtocol {
    func execute(jpegData: Data) async throws -> URL? { nil }
}

private final class StubDashboardUseCase: GetHomeDashboardUseCaseProtocol {
    var result: Result<HomeDashboard, Error>
    private(set) var callCount = 0

    init(result: Result<HomeDashboard, Error>) {
        self.result = result
    }

    func execute() async throws -> HomeDashboard {
        callCount += 1
        return try result.get()
    }
}

private final class StubMyProfile: GetMyProfileUseCaseProtocol {
    var result: Result<UserProfile, Error>
    private(set) var callCount = 0
    init(_ result: Result<UserProfile, Error>) { self.result = result }
    func execute() async throws -> UserProfile {
        callCount += 1
        return try result.get()
    }
}

private final class SpyPronunciation: PronunciationServiceProtocol {
    private(set) var spoken: [String] = []
    func speak(_ text: String, slow: Bool) { spoken.append(text) }
    func play(url: URL?, fallbackText text: String, slow: Bool) { spoken.append(text) }
}

@MainActor
final class HomeDashboardTests: XCTestCase {
    private var dashboardUseCase: StubDashboardUseCase!
    private var pronunciation: SpyPronunciation!
    private var myProfile: StubMyProfile!
    /// Mặc định API Từ của ngày lỗi → dùng từ trong dashboard.
    private var wordOfTheDayLoader: () async throws -> VocabEntry = { throw URLError(.badServerResponse) }

    override func setUp() async throws {
        dashboardUseCase = StubDashboardUseCase(result: .success(try await MockHomeRepository().dashboard()))
        pronunciation = SpyPronunciation()
        myProfile = StubMyProfile(.success(UserProfile(
            id: "u1", fullName: "Trần Thị Bích Ngọc", email: "ngoc@example.com", username: "ngoc",
            phone: nil, birthDate: nil, avatarURL: URL(string: "https://cdn.example.com/n.jpg")
        )))
    }

    private func makeSUT(fullName: String? = "Nguyễn Minh Anh", today: Date = Date()) -> HomeViewModel {
        HomeViewModel(
            user: fullName.map { User(id: "u1", fullName: $0, username: "u") },
            logoutUseCase: NoopLogoutUseCase(),
            uploadAvatarUseCase: NoopUploadAvatarUseCase(),
            getDashboardUseCase: dashboardUseCase,
            getMyProfileUseCase: myProfile,
            pronunciation: pronunciation,
            loadWordOfTheDay: wordOfTheDayLoader,
            today: today,
            onLoggedOut: {}
        )
    }

    func test_greeting_usesLastTwoWordsOfFullName() {
        let sut = makeSUT()
        XCTAssertEqual(sut.greeting, "Chào, Minh Anh")
        XCTAssertEqual(sut.initials, "MA")
    }

    func test_greeting_shortName_usesWholeName() {
        let sut = makeSUT(fullName: "An")
        XCTAssertEqual(sut.greeting, "Chào, An")
        XCTAssertEqual(sut.initials, "A")
    }

    func test_greeting_withoutUser() {
        let sut = makeSUT(fullName: nil)
        XCTAssertEqual(sut.greeting, "Xin chào")
        XCTAssertEqual(sut.initials, "")
    }

    func test_dateText_isVietnameseUppercased() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 18
        components.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: components)!
        XCTAssertEqual(makeSUT(today: date).dateText, "THỨ TƯ, 18 THÁNG 11")
    }

    func test_loadDashboard_loadsOnce() async {
        let sut = makeSUT()

        await sut.loadDashboard()
        await sut.loadDashboard()

        XCTAssertEqual(dashboardUseCase.callCount, 1)
        XCTAssertEqual(sut.dashboard?.streakDays, 7)
        XCTAssertFalse(sut.isLoadingDashboard)
    }

    func test_loadDashboard_failure_leavesDashboardEmpty() async {
        dashboardUseCase.result = .failure(URLError(.notConnectedToInternet))
        let sut = makeSUT()

        await sut.loadDashboard()

        XCTAssertNil(sut.dashboard)
    }

    func test_playWordOfTheDay_speaksHanzi() async {
        let sut = makeSUT()
        sut.playWordOfTheDay()
        XCTAssertTrue(pronunciation.spoken.isEmpty)

        await sut.loadDashboard()
        sut.playWordOfTheDay()

        XCTAssertEqual(pronunciation.spoken, ["学习"])
    }

    func test_wordOfTheDay_fromAPI_takesPriority_andPlaysAudio() async {
        let word = VocabWord(
            id: "hsk1-200", level: 1, entryNumber: 200, hanzi: "牛", pinyin: "niú", meaning: "bò",
            decomposition: [CharacterDecomposition(character: "牛", hanViet: "ngưu",
                                                   components: [.init(character: "牛", hanViet: "ngưu", meaning: "con bò")],
                                                   mnemonic: "Hai sừng nhô ra từ đầu con bò.")],
            audioURL: URL(string: "http://localhost:8081/audio/hsk/1/200.m4a")
        )
        wordOfTheDayLoader = { VocabEntry(word: word, status: .notStarted) }
        let sut = makeSUT()

        await sut.loadDashboard()
        sut.playWordOfTheDay()

        XCTAssertEqual(sut.wordOfTheDay?.word.hanzi, "牛")
        XCTAssertEqual(sut.wordOfTheDay?.word.decomposition.first?.components.first?.meaning, "con bò")
        XCTAssertEqual(pronunciation.spoken, ["牛"])
    }

    func test_loadProfile_updatesNameEmailAndAvatar() async {
        let sut = makeSUT()

        await sut.loadProfile()
        await sut.loadProfile()

        XCTAssertEqual(myProfile.callCount, 1)
        XCTAssertEqual(sut.greeting, "Chào, Bích Ngọc")
        XCTAssertEqual(sut.accountSubtitle, "ngoc@example.com")
        XCTAssertEqual(sut.avatarURL?.absoluteString, "https://cdn.example.com/n.jpg")

        await sut.loadProfile(force: true)
        XCTAssertEqual(myProfile.callCount, 2)
    }

    func test_loadProfile_failure_keepsLoginUser_andShowsError() async {
        myProfile.result = .failure(ProfileError.network)
        let sut = makeSUT()

        await sut.loadProfile()

        XCTAssertEqual(sut.greeting, "Chào, Minh Anh")
        XCTAssertEqual(sut.profileErrorMessage, ProfileError.network.errorDescription)
    }

    func test_loadProfile_sessionExpired_showsNoError() async {
        myProfile.result = .failure(ProfileError.sessionExpired)
        let sut = makeSUT()

        await sut.loadProfile()

        XCTAssertNil(sut.profileErrorMessage)
    }

    func test_dailyGoal_fraction_isClamped() {
        XCTAssertEqual(DailyGoal(studiedMinutes: 10, targetMinutes: 15).fraction, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(DailyGoal(studiedMinutes: 30, targetMinutes: 15).fraction, 1)
        XCTAssertEqual(DailyGoal(studiedMinutes: 5, targetMinutes: 0).fraction, 0)
    }
}
