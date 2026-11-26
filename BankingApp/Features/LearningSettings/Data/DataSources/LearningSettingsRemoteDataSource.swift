import Foundation

protocol LearningSettingsRemoteDataSource {
    func get() async throws -> LearningSettingsDTO
    func put(_ body: LearningSettingsPutDTO) async throws -> LearningSettingsDTO
}

final class LearningSettingsRemoteDataSourceImpl: LearningSettingsRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func get() async throws -> LearningSettingsDTO {
        try await client.request(LearningSettingsEndpoint.get, as: LearningSettingsDTO.self)
    }

    func put(_ body: LearningSettingsPutDTO) async throws -> LearningSettingsDTO {
        try await client.request(LearningSettingsEndpoint.put(body), as: LearningSettingsDTO.self)
    }
}

/// Backend giả (USE_MOCK_API = YES): lưu trong bộ nhớ, kiểm tra giống server
/// (mục tiêu 5–120, bật nhắc phải có ít nhất 1 ngày, múi giờ phải tồn tại), bỏ trùng và sắp xếp `days`.
final class MockLearningSettingsRemoteDataSource: LearningSettingsRemoteDataSource {
    private var stored = LearningSettingsDTO(.default)
    private let delay: Duration

    init(delay: Duration = .milliseconds(500)) {
        self.delay = delay
    }

    func get() async throws -> LearningSettingsDTO {
        try await Task.sleep(for: delay)
        return stored
    }

    func put(_ body: LearningSettingsPutDTO) async throws -> LearningSettingsDTO {
        try await Task.sleep(for: delay)
        guard (5...120).contains(body.dailyGoalMinutes) else { throw Self.error("Invalid request content.") }
        guard TimeZone(identifier: body.reminder.timezone) != nil else {
            throw Self.error("Múi giờ không hợp lệ, ví dụ: Asia/Ho_Chi_Minh")
        }
        if body.reminder.enabled && body.reminder.days.isEmpty {
            throw Self.error("Vui lòng chọn ít nhất 1 ngày nhắc học")
        }
        var settings = LearningSettingsDTO(
            dailyGoalMinutes: body.dailyGoalMinutes, reminder: body.reminder,
            script: body.script, pinyinMode: body.pinyinMode
        ).toDomain()
        settings.updatedAt = Date()
        stored = LearningSettingsDTO(settings)
        return stored
    }

    private static func error(_ message: String) -> NetworkError {
        .api(code: 400, httpStatus: 400, message: message, traceId: nil)
    }
}

extension LearningSettingsDTO {
    init(dailyGoalMinutes: Int, reminder: ReminderDTO, script: String, pinyinMode: String, updatedAt: String? = nil) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.reminder = reminder
        self.script = script
        self.pinyinMode = pinyinMode
        self.updatedAt = updatedAt
    }
}
