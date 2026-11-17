import Foundation

/// Danh sách tiện ích tĩnh. Khi có API cấu hình menu từ server,
/// thêm RemoteDataSource vào đây mà không cần sửa Domain/Presentation.
final class UtilitiesRepositoryImpl: UtilitiesRepository {
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func publicUtilities() async throws -> [UtilityItem] {
        [
            UtilityItem(id: "dict", kind: .dictionary, title: "Tra từ điển"),
            UtilityItem(id: "pinyin", kind: .pinyinChart, title: "Bảng phiên âm Pinyin"),
            UtilityItem(id: "tone", kind: .tonePractice, title: "Luyện thanh điệu"),
            UtilityItem(id: "write", kind: .handwriting, title: "Tập viết chữ Hán"),
            UtilityItem(id: "radical", kind: .radicals, title: "Bộ thủ"),
            UtilityItem(id: "hsk", kind: .hskVocabulary, title: "Từ vựng HSK"),
        ]
    }

    func supportContact() -> SupportContact {
        SupportContact(title: "Góp ý & hỗ trợ", email: config.supportEmail)
    }
}
