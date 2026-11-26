import Factory
import Foundation
import Observation

/// Cài đặt học dùng chung cho Trang chủ, tab Cá nhân và 3 màn cài đặt.
/// Mở app hiện ngay bản trên máy, rồi tải bản mới từ server.
@MainActor
@Observable
final class LearningSettingsStore {
    private(set) var settings: LearningSettings
    private(set) var isLoading = false
    private(set) var hasLoadedFromServer = false
    /// Cỡ chữ Hán (pt), chỉ lưu trên máy.
    private(set) var hanziFontSize: Double

    static let fontSizeRange: ClosedRange<Double> = 28...44
    static let defaultFontSize: Double = 36

    private let useCase: LearningSettingsUseCaseProtocol
    private let scheduler: ReminderScheduling

    init(
        useCase: LearningSettingsUseCaseProtocol = Container.shared.learningSettingsUseCase(),
        scheduler: ReminderScheduling = Container.shared.reminderScheduler()
    ) {
        self.useCase = useCase
        self.scheduler = scheduler
        settings = useCase.cached() ?? .default
        hanziFontSize = useCase.hanziFontSize() ?? Self.defaultFontSize
    }

    /// Tải từ server. Lỗi (mạng...) thì giữ bản đang có, không báo.
    func load(force: Bool = false) async {
        guard !isLoading, force || !hasLoadedFromServer else { return }
        isLoading = true
        defer { isLoading = false }
        guard let fresh = try? await useCase.fetch() else { return }
        settings = fresh
        hasLoadedFromServer = true
        await scheduler.reschedule(fresh)
    }

    /// Lưu lên server. Thành công thì cập nhật và hẹn lại giờ nhắc; lỗi thì giữ nguyên bản cũ và ném lỗi.
    func save(_ new: LearningSettings) async throws {
        var draft = new
        // Giờ nhắc là giờ địa phương theo múi giờ hiện tại của máy.
        draft.reminder.timezone = TimeZone.current.identifier
        do {
            let saved = try await useCase.save(draft)
            settings = saved
            await scheduler.reschedule(saved)
        } catch {
            throw LearningSettingsRepositoryImpl.map(error)
        }
    }

    /// Đăng xuất: huỷ lịch nhắc trên máy và về giá trị mặc định (tài khoản sau tải lại từ server).
    func signOut() async {
        var cleared = settings
        cleared.reminder.enabled = false
        await scheduler.reschedule(cleared)
        settings = .default
        hasLoadedFromServer = false
    }

    func setHanziFontSize(_ size: Double) {
        let clamped = min(max(size, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        hanziFontSize = clamped
        useCase.setHanziFontSize(clamped)
    }

    func notificationPermission() async -> NotificationPermission {
        await scheduler.permission()
    }

    func requestNotificationPermission() async -> Bool {
        await scheduler.requestPermission()
    }
}
