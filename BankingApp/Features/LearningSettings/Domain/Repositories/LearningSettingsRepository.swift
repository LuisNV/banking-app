import Foundation

protocol LearningSettingsRepository {
    /// Bản đã lưu trên máy (mở app hiện ngay, kể cả khi offline).
    func cachedSettings() -> LearningSettings?
    /// Tải từ server và cập nhật bản trên máy.
    func fetch() async throws -> LearningSettings
    /// Ghi đè toàn bộ lên server; trả về bản server đã chuẩn hoá và cập nhật bản trên máy.
    func save(_ settings: LearningSettings) async throws -> LearningSettings

    /// Cỡ chữ Hán: chỉ lưu trên máy.
    func hanziFontSize() -> Double?
    func setHanziFontSize(_ size: Double)
}
