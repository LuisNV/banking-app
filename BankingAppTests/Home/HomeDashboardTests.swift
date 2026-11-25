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

private final class SpyPronunciation: PronunciationServiceProtocol {
    private(set) var spoken: [String] = []
    func speak(_ text: String) { spoken.append(text) }
}

@MainActor
final class HomeDashboardTests: XCTestCase {
    private var dashboardUseCase: StubDashboardUseCase!
    private var pronunciation: SpyPronunciation!

    override func setUp() async throws {
        dashboardUseCase = StubDashboardUseCase(result: .success(try await MockHomeRepository().dashboard()))
        pronunciation = SpyPronunciation()
    }

    private func makeSUT(fullName: String? = "Nguyễn Minh Anh", today: Date = Date()) -> HomeViewModel {
        HomeViewModel(
            user: fullName.map { User(id: "u1", fullName: $0, username: "u") },
            logoutUseCase: NoopLogoutUseCase(),
            uploadAvatarUseCase: NoopUploadAvatarUseCase(),
            getDashboardUseCase: dashboardUseCase,
            pronunciation: pronunciation,
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

    func test_dailyGoal_fraction_isClamped() {
        XCTAssertEqual(DailyGoal(studiedMinutes: 10, targetMinutes: 15).fraction, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(DailyGoal(studiedMinutes: 30, targetMinutes: 15).fraction, 1)
        XCTAssertEqual(DailyGoal(studiedMinutes: 5, targetMinutes: 0).fraction, 0)
    }
}
