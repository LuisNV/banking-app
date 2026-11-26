import Foundation

/// Dạng JSON của cài đặt học: dùng cho `data` của GET/PUT, body của PUT và bản lưu trên máy.
struct LearningSettingsDTO: Codable, Equatable {
    struct ReminderDTO: Codable, Equatable {
        let enabled: Bool
        /// "HH:mm"
        let time: String
        /// "MON" … "SUN"
        let days: [String]
        let skipIfGoalMet: Bool
        let timezone: String
    }

    let dailyGoalMinutes: Int
    let reminder: ReminderDTO
    let script: String
    let pinyinMode: String
    /// Chỉ có ở response. Không gửi lên khi PUT.
    var updatedAt: String?

    init(_ settings: LearningSettings) {
        dailyGoalMinutes = settings.dailyGoalMinutes
        reminder = ReminderDTO(
            enabled: settings.reminder.enabled,
            time: settings.reminder.time.string,
            days: settings.reminder.days.sorted().map(\.rawValue),
            skipIfGoalMet: settings.reminder.skipIfGoalMet,
            timezone: settings.reminder.timezone
        )
        script = settings.script.rawValue
        pinyinMode = settings.pinyinMode.rawValue
        updatedAt = settings.updatedAt.map { ISO8601DateFormatter().string(from: $0) }
    }

    func toDomain() -> LearningSettings {
        let fallback = LearningSettings.default
        return LearningSettings(
            dailyGoalMinutes: dailyGoalMinutes,
            reminder: StudyReminder(
                enabled: reminder.enabled,
                time: ReminderTime(string: reminder.time) ?? fallback.reminder.time,
                days: Set(reminder.days.compactMap { Weekday(rawValue: $0.uppercased()) }),
                skipIfGoalMet: reminder.skipIfGoalMet,
                timezone: reminder.timezone
            ),
            script: HanziScript(rawValue: script.uppercased()) ?? fallback.script,
            pinyinMode: PinyinMode(rawValue: pinyinMode.uppercased()) ?? fallback.pinyinMode,
            updatedAt: updatedAt.flatMap(RegistrationResponseDTO.parseDate)
        )
    }

    /// Body của PUT: mọi trường bắt buộc, không kèm `updatedAt`.
    var putBody: LearningSettingsPutDTO {
        LearningSettingsPutDTO(dailyGoalMinutes: dailyGoalMinutes, reminder: reminder, script: script, pinyinMode: pinyinMode)
    }
}

struct LearningSettingsPutDTO: Encodable, Equatable {
    let dailyGoalMinutes: Int
    let reminder: LearningSettingsDTO.ReminderDTO
    let script: String
    let pinyinMode: String
}
