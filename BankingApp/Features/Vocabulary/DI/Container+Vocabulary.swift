import Factory
import Foundation

extension Container {
    /// Chưa có API từ vựng: luôn dùng dữ liệu mẫu. Khi có API, thêm `VocabularyRepositoryImpl`
    /// và chọn theo `appConfig().useMockAPI` như các feature khác.
    var vocabularyRepository: Factory<any VocabularyRepository> {
        self { MockVocabularyRepository() }.singleton
    }
}
