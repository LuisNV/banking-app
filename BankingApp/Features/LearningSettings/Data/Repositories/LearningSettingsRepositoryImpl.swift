import Foundation

final class LearningSettingsRepositoryImpl: LearningSettingsRepository {
    private enum Key {
        static let cache = "learning_settings.cache"
        static let hanziFontSize = "learning_settings.hanzi_font_size"
    }

    private let remote: LearningSettingsRemoteDataSource
    private let keyValueStore: KeyValueStore

    init(remote: LearningSettingsRemoteDataSource, keyValueStore: KeyValueStore) {
        self.remote = remote
        self.keyValueStore = keyValueStore
    }

    func cachedSettings() -> LearningSettings? {
        guard let json = keyValueStore.string(forKey: Key.cache),
              let dto = try? JSONDecoder().decode(LearningSettingsDTO.self, from: Data(json.utf8))
        else { return nil }
        return dto.toDomain()
    }

    func fetch() async throws -> LearningSettings {
        do {
            let dto = try await remote.get()
            store(dto)
            return dto.toDomain()
        } catch {
            throw Self.map(error)
        }
    }

    func save(_ settings: LearningSettings) async throws -> LearningSettings {
        do {
            let dto = try await remote.put(LearningSettingsDTO(settings).putBody)
            store(dto)
            return dto.toDomain()
        } catch {
            throw Self.map(error)
        }
    }

    func hanziFontSize() -> Double? {
        guard let text = keyValueStore.string(forKey: Key.hanziFontSize) else { return nil }
        return Double(text)
    }

    func setHanziFontSize(_ size: Double) {
        keyValueStore.set(String(size), forKey: Key.hanziFontSize)
    }

    /// Đăng xuất: xoá bản trên máy của tài khoản cũ.
    func clearCache() {
        keyValueStore.removeObject(forKey: Key.cache)
    }

    private func store(_ dto: LearningSettingsDTO) {
        guard let data = try? JSONEncoder().encode(dto), let json = String(data: data, encoding: .utf8) else { return }
        keyValueStore.set(json, forKey: Key.cache)
    }

    /// Lỗi validate của Spring trả câu tiếng Anh ("Invalid request content.", "Failed to read request"):
    /// thay bằng câu tiếng Việt; lỗi kiểm tra trong service (múi giờ, ngày nhắc) giữ nguyên câu của server.
    static func map(_ error: Error) -> LearningSettingsError {
        if let settingsError = error as? LearningSettingsError { return settingsError }
        guard let networkError = error as? NetworkError else { return .unknown }
        switch networkError {
        case .unauthorized:
            return .sessionExpired
        case .api(_, let httpStatus, let message, _):
            switch httpStatus {
            case 400:
                return .invalid(message: isVietnamese(message) ? message : "Cài đặt không hợp lệ. Vui lòng kiểm tra lại.")
            case 401: return .sessionExpired
            case 404: return .accountNotFound
            default: return .unknown
            }
        case .noConnection, .timeout: return .network
        case .server, .decoding, .unknown: return .unknown
        }
    }

    /// Câu có dấu tiếng Việt (ký tự ngoài ASCII) thì coi là câu do backend viết.
    private static func isVietnamese(_ message: String) -> Bool {
        !message.isEmpty && message.unicodeScalars.contains { !$0.isASCII }
    }
}
