import XCTest
@testable import BankingApp

// MARK: - DTO, endpoint, mã lỗi

final class LearningSettingsDataTests: XCTestCase {
    func test_decode_defaultResponse_withNullUpdatedAt() throws {
        let json = """
        {"code":0,"httpStatus":200,"message":"Thành công","data":{
          "dailyGoalMinutes":15,
          "reminder":{"enabled":false,"time":"20:00","days":["MON","TUE","WED","THU","FRI","SAT","SUN"],
                      "skipIfGoalMet":true,"timezone":"Asia/Ho_Chi_Minh"},
          "script":"SIMPLIFIED","pinyinMode":"ALWAYS","updatedAt":null},"traceId":"t"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let settings = try XCTUnwrap(decoder.decode(APIResponse<LearningSettingsDTO>.self, from: Data(json.utf8)).data).toDomain()

        XCTAssertEqual(settings.dailyGoalMinutes, 15)
        XCTAssertFalse(settings.reminder.enabled)
        XCTAssertEqual(settings.reminder.time, ReminderTime(hour: 20, minute: 0))
        XCTAssertEqual(settings.reminder.days, Set(Weekday.allCases))
        XCTAssertEqual(settings.reminder.timezone, "Asia/Ho_Chi_Minh")
        XCTAssertEqual(settings.script, .simplified)
        XCTAssertEqual(settings.pinyinMode, .always)
        XCTAssertNil(settings.updatedAt)
    }

    func test_putBody_matchesCurl() throws {
        var settings = LearningSettings.default
        settings.reminder = StudyReminder(
            enabled: true, time: ReminderTime(hour: 20, minute: 0),
            days: [.sat, .mon, .wed, .tue, .fri, .thu], skipIfGoalMet: true, timezone: "Asia/Ho_Chi_Minh"
        )
        settings.updatedAt = Date()
        let endpoint = LearningSettingsEndpoint.put(LearningSettingsDTO(settings).putBody)

        XCTAssertEqual(endpoint.path, "v1/users/me/learning-settings")
        XCTAssertEqual(endpoint.method.rawValue, "PUT")
        XCTAssertTrue(endpoint.requiresAuth)
        XCTAssertEqual(LearningSettingsEndpoint.get.method.rawValue, "GET")

        let body = try XCTUnwrap(endpoint.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AnyEncodable(body))) as? NSDictionary)
        let expected: NSDictionary = [
            "dailyGoalMinutes": 15,
            "reminder": [
                "enabled": true, "time": "20:00",
                "days": ["MON", "TUE", "WED", "THU", "FRI", "SAT"],
                "skipIfGoalMet": true, "timezone": "Asia/Ho_Chi_Minh",
            ],
            "script": "SIMPLIFIED",
            "pinyinMode": "ALWAYS",
        ]
        XCTAssertEqual(json, expected, "Không gửi updatedAt, days sắp theo MON → SUN")
    }

    func test_reminderTime_parsing() {
        XCTAssertEqual(ReminderTime(string: "07:05"), ReminderTime(hour: 7, minute: 5))
        XCTAssertEqual(ReminderTime(hour: 7, minute: 5).string, "07:05")
        XCTAssertNil(ReminderTime(string: "24:00"))
        XCTAssertNil(ReminderTime(string: "abc"))
    }

    func test_weekday_calendarMapping() {
        XCTAssertEqual(Weekday.sun.calendarWeekday, 1)
        XCTAssertEqual(Weekday.mon.calendarWeekday, 2)
        XCTAssertEqual([Weekday.sun, .mon, .wed].sorted(), [.mon, .wed, .sun])
    }

    func test_validator() {
        var settings = LearningSettings.default
        XCTAssertNil(LearningSettingsValidator.error(for: settings))
        settings.dailyGoalMinutes = 121
        XCTAssertNotNil(LearningSettingsValidator.error(for: settings))
        settings.dailyGoalMinutes = 15
        settings.reminder.enabled = true
        settings.reminder.days = []
        XCTAssertEqual(LearningSettingsValidator.error(for: settings), "Vui lòng chọn ít nhất 1 ngày nhắc học")
        settings.reminder.days = [.mon]
        settings.reminder.timezone = "Mars/Base"
        XCTAssertNotNil(LearningSettingsValidator.error(for: settings))
    }

    /// Câu tiếng Việt của server giữ nguyên; câu mặc định tiếng Anh của Spring đổi sang tiếng Việt.
    func test_mapsErrors() {
        func api(_ status: Int, _ message: String) -> NetworkError {
            .api(code: status, httpStatus: status, message: message, traceId: nil)
        }
        typealias Repo = LearningSettingsRepositoryImpl
        XCTAssertEqual(Repo.map(api(400, "Múi giờ không hợp lệ, ví dụ: Asia/Ho_Chi_Minh")),
                       .invalid(message: "Múi giờ không hợp lệ, ví dụ: Asia/Ho_Chi_Minh"))
        XCTAssertEqual(Repo.map(api(400, "Invalid request content.")),
                       .invalid(message: "Cài đặt không hợp lệ. Vui lòng kiểm tra lại."))
        XCTAssertEqual(Repo.map(api(400, "Failed to read request")),
                       .invalid(message: "Cài đặt không hợp lệ. Vui lòng kiểm tra lại."))
        XCTAssertEqual(Repo.map(api(404, "Không tìm thấy người dùng")), .accountNotFound)
        XCTAssertEqual(Repo.map(api(500, "Lỗi hệ thống")), .unknown)
        XCTAssertEqual(Repo.map(NetworkError.noConnection), .network)
    }
}

// MARK: - Store

private final class StubSettingsUseCase: LearningSettingsUseCaseProtocol {
    var cachedValue: LearningSettings?
    var fetchResult: Result<LearningSettings, Error> = .success(.default)
    var saveResult: Result<LearningSettings, Error>?
    private(set) var saved: [LearningSettings] = []
    var fontSize: Double?

    func cached() -> LearningSettings? { cachedValue }
    func fetch() async throws -> LearningSettings { try fetchResult.get() }

    func save(_ settings: LearningSettings) async throws -> LearningSettings {
        saved.append(settings)
        if let saveResult { return try saveResult.get() }
        var result = settings
        result.updatedAt = Date()
        return result
    }

    func hanziFontSize() -> Double? { fontSize }
    func setHanziFontSize(_ size: Double) { fontSize = size }
}

private final class SpyScheduler: ReminderScheduling {
    private(set) var scheduled: [LearningSettings] = []
    func permission() async -> NotificationPermission { .allowed }
    func requestPermission() async -> Bool { true }
    func reschedule(_ settings: LearningSettings) async { scheduled.append(settings) }
}

@MainActor
final class LearningSettingsStoreTests: XCTestCase {
    private var useCase: StubSettingsUseCase!
    private var scheduler: SpyScheduler!

    override func setUp() {
        super.setUp()
        useCase = StubSettingsUseCase()
        scheduler = SpyScheduler()
    }

    private func makeSUT() -> LearningSettingsStore {
        LearningSettingsStore(useCase: useCase, scheduler: scheduler)
    }

    func test_startsWithCache_thenLoadsFromServer() async {
        var cached = LearningSettings.default
        cached.dailyGoalMinutes = 20
        useCase.cachedValue = cached
        var fresh = LearningSettings.default
        fresh.dailyGoalMinutes = 30
        useCase.fetchResult = .success(fresh)

        let sut = makeSUT()
        XCTAssertEqual(sut.settings.dailyGoalMinutes, 20, "Mở app hiện ngay bản trên máy")

        await sut.load()
        XCTAssertEqual(sut.settings.dailyGoalMinutes, 30)
        XCTAssertEqual(scheduler.scheduled.last?.dailyGoalMinutes, 30)
    }

    func test_loadFailure_keepsCurrentSettings() async {
        useCase.fetchResult = .failure(LearningSettingsError.network)
        let sut = makeSUT()

        await sut.load()

        XCTAssertEqual(sut.settings, .default)
        XCTAssertFalse(sut.hasLoadedFromServer)
    }

    func test_save_usesDeviceTimezone_andReschedules() async throws {
        let sut = makeSUT()
        var updated = sut.settings
        updated.reminder.enabled = true
        updated.reminder.timezone = "Asia/Tokyo"

        try await sut.save(updated)

        XCTAssertEqual(useCase.saved.first?.reminder.timezone, TimeZone.current.identifier)
        XCTAssertTrue(sut.settings.reminder.enabled)
        XCTAssertTrue(scheduler.scheduled.last?.reminder.enabled ?? false)
    }

    func test_saveFailure_keepsOldSettings_andThrows() async {
        useCase.saveResult = .failure(NetworkError.api(code: 400, httpStatus: 400, message: "Vui lòng chọn ít nhất 1 ngày nhắc học", traceId: nil))
        let sut = makeSUT()
        var updated = sut.settings
        updated.dailyGoalMinutes = 30

        do {
            try await sut.save(updated)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? LearningSettingsError, .invalid(message: "Vui lòng chọn ít nhất 1 ngày nhắc học"))
        }
        XCTAssertEqual(sut.settings.dailyGoalMinutes, 15)
    }

    func test_fontSize_isLocalOnly_andClamped() {
        let sut = makeSUT()
        sut.setHanziFontSize(100)
        XCTAssertEqual(sut.hanziFontSize, LearningSettingsStore.fontSizeRange.upperBound)
        XCTAssertEqual(useCase.fontSize, LearningSettingsStore.fontSizeRange.upperBound)
        XCTAssertTrue(useCase.saved.isEmpty)
    }

    func test_signOut_cancelsReminders() async throws {
        let sut = makeSUT()
        var updated = sut.settings
        updated.reminder.enabled = true
        try await sut.save(updated)

        await sut.signOut()

        XCTAssertEqual(scheduler.scheduled.last?.reminder.enabled, false)
        XCTAssertEqual(sut.settings, .default)
    }
}
