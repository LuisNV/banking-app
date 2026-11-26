import Foundation

/// Cài đặt học của người dùng (`/v1/users/me/learning-settings`). Lưu trên server, có bản sao trên máy.
struct LearningSettings: Equatable {
    var dailyGoalMinutes: Int
    var reminder: StudyReminder
    var script: HanziScript
    var pinyinMode: PinyinMode
    /// `nil`: người dùng chưa lưu lần nào (server trả giá trị mặc định).
    var updatedAt: Date?

    static let `default` = LearningSettings(
        dailyGoalMinutes: 15,
        reminder: StudyReminder(
            enabled: false,
            time: ReminderTime(hour: 20, minute: 0),
            days: Set(Weekday.allCases),
            skipIfGoalMet: true,
            timezone: TimeZone.current.identifier
        ),
        script: .simplified,
        pinyinMode: .always,
        updatedAt: nil
    )

    /// Các mức chọn nhanh trên màn Mục tiêu.
    static let goalPresets = [5, 10, 15, 20, 30]
    static let goalRange = 5...120
}

struct StudyReminder: Equatable {
    var enabled: Bool
    var time: ReminderTime
    var days: Set<Weekday>
    var skipIfGoalMet: Bool
    /// Múi giờ IANA, vd. "Asia/Ho_Chi_Minh". Giờ nhắc là giờ địa phương theo múi giờ này.
    var timezone: String
}

/// Giờ nhắc dạng "HH:mm" (giờ địa phương).
struct ReminderTime: Equatable, Comparable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// "20:00" → 20:00. Sai định dạng thì `nil`.
    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    var string: String { String(format: "%02d:%02d", hour, minute) }

    static func < (lhs: ReminderTime, rhs: ReminderTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

enum Weekday: String, CaseIterable, Comparable {
    case mon = "MON", tue = "TUE", wed = "WED", thu = "THU", fri = "FRI", sat = "SAT", sun = "SUN"

    /// T2 … CN
    var shortTitle: String {
        switch self {
        case .mon: return "T2"
        case .tue: return "T3"
        case .wed: return "T4"
        case .thu: return "T5"
        case .fri: return "T6"
        case .sat: return "T7"
        case .sun: return "CN"
        }
    }

    var title: String {
        switch self {
        case .mon: return "Thứ Hai"
        case .tue: return "Thứ Ba"
        case .wed: return "Thứ Tư"
        case .thu: return "Thứ Năm"
        case .fri: return "Thứ Sáu"
        case .sat: return "Thứ Bảy"
        case .sun: return "Chủ nhật"
        }
    }

    /// `Calendar.component(.weekday)`: Chủ nhật = 1 … Thứ Bảy = 7.
    var calendarWeekday: Int {
        switch self {
        case .sun: return 1
        case .mon: return 2
        case .tue: return 3
        case .wed: return 4
        case .thu: return 5
        case .fri: return 6
        case .sat: return 7
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.order < rhs.order }
}

enum HanziScript: String, CaseIterable {
    case simplified = "SIMPLIFIED", traditional = "TRADITIONAL"

    var title: String { self == .simplified ? "Giản thể" : "Phồn thể" }
    var region: String {
        self == .simplified ? "Trung Quốc đại lục, Singapore" : "Đài Loan, Hồng Kông, Ma Cao"
    }
    /// Chữ mẫu "học tập".
    var sample: String { self == .simplified ? "学习" : "學習" }
}

enum PinyinMode: String, CaseIterable {
    case always = "ALWAYS", onTap = "ON_TAP", never = "NEVER"

    var title: String {
        switch self {
        case .always: return "Luôn hiện"
        case .onTap: return "Khi chạm"
        case .never: return "Ẩn"
        }
    }

    var hint: String {
        switch self {
        case .always: return "Pinyin luôn hiện phía trên chữ Hán."
        case .onTap: return "Chạm vào chữ để hiện pinyin. Tốt để tự kiểm tra cách đọc."
        case .never: return "Không hiện pinyin. Dành cho khi bạn đã đọc thạo."
        }
    }
}

enum LearningSettingsValidator {
    /// Lỗi đầu tiên (nếu có) theo ràng buộc của server.
    static func error(for settings: LearningSettings) -> String? {
        if !LearningSettings.goalRange.contains(settings.dailyGoalMinutes) {
            return "Mục tiêu mỗi ngày từ \(LearningSettings.goalRange.lowerBound) đến \(LearningSettings.goalRange.upperBound) phút."
        }
        if settings.reminder.enabled && settings.reminder.days.isEmpty {
            return "Vui lòng chọn ít nhất 1 ngày nhắc học"
        }
        if TimeZone(identifier: settings.reminder.timezone) == nil {
            return "Múi giờ không hợp lệ, ví dụ: Asia/Ho_Chi_Minh"
        }
        return nil
    }
}

enum LearningSettingsError: LocalizedError, Equatable {
    case invalid(message: String)
    case accountNotFound
    case sessionExpired
    case network
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .accountNotFound: return "Không tìm thấy tài khoản. Vui lòng đăng nhập lại."
        case .sessionExpired: return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .network: return "Không thể kết nối. Cài đặt chưa được lưu, vui lòng thử lại."
        case .unknown: return "Không thể lưu cài đặt. Vui lòng thử lại."
        }
    }
}
