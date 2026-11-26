import Foundation
import UserNotifications

enum NotificationPermission: Equatable {
    case notDetermined, allowed, denied
}

/// Hẹn giờ nhắc học bằng thông báo cục bộ (không cần server).
protocol ReminderScheduling {
    func permission() async -> NotificationPermission
    /// Hỏi quyền nếu chưa hỏi. `true` nếu được phép.
    func requestPermission() async -> Bool
    /// Xoá lịch cũ rồi hẹn lại theo cài đặt (tắt nhắc hoặc chưa có quyền thì chỉ xoá).
    func reschedule(_ settings: LearningSettings) async
}

final class LocalReminderScheduler: ReminderScheduling {
    static let identifierPrefix = "study-reminder-"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func reschedule(_ settings: LearningSettings) async {
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        let reminder = settings.reminder
        guard reminder.enabled, await permission() == .allowed else { return }

        let content = UNMutableNotificationContent()
        content.title = "Đến giờ học rồi!"
        content.body = "Dành \(settings.dailyGoalMinutes) phút học tiếng Trung để giữ chuỗi ngày học nhé."
        content.sound = .default

        // Lặp hằng tuần vào các ngày đã chọn, theo giờ của máy.
        // TODO: "Bỏ qua nếu đã học xong" cần biết tiến độ trong ngày; khi có push từ server (FCM)
        // thì server lo phần này. Với thông báo cục bộ, có thể huỷ thông báo hôm nay khi đạt mục tiêu.
        for day in reminder.days.sorted() {
            var components = DateComponents()
            components.weekday = day.calendarWeekday
            components.hour = reminder.time.hour
            components.minute = reminder.time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + day.rawValue,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
