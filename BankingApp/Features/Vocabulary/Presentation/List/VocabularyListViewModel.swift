import Factory
import Foundation
import Observation

@Observable
@MainActor
final class VocabularyListViewModel {
    enum Filter: CaseIterable, Hashable {
        case all, notStarted, learning, known

        var title: String {
            switch self {
            case .all: return "Tất cả"
            case .notStarted: return "Chưa học"
            case .learning: return "Đang học"
            case .known: return "Đã thuộc"
            }
        }

        func includes(_ status: VocabStatus) -> Bool {
            switch self {
            case .all: return true
            case .notStarted: return status == .notStarted
            case .learning: return status == .learning
            case .known: return status == .known
            }
        }
    }

    struct TopicGroup: Identifiable {
        let topic: String
        let entries: [VocabEntry]
        var id: String { topic }
    }

    /// Các cấp hiển thị trên thanh chọn; cấp chưa có dữ liệu bị khoá ("sắp có").
    let allLevels = [1, 2, 3, 4, 5, 6]
    let level = 1

    private(set) var availableLevels: [Int] = [1]
    private(set) var entries: [VocabEntry] = []
    private(set) var summary: VocabSummary = .empty
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var filter: Filter = .all

    private let repository: any VocabularyRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        repository: any VocabularyRepository = Container.shared.vocabularyRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var topics: [String] {
        var seen: [String] = []
        for entry in entries where !seen.contains(entry.word.topic) {
            seen.append(entry.word.topic)
        }
        return seen
    }

    var groups: [TopicGroup] {
        topics.compactMap { topic in
            let items = entries.filter { $0.word.topic == topic && filter.includes($0.status) }
            return items.isEmpty ? nil : TopicGroup(topic: topic, entries: items)
        }
    }

    /// Danh sách đang hiện (theo bộ lọc), dùng cho nút trước/sau ở màn chi tiết.
    var visibleEntries: [VocabEntry] { groups.flatMap(\.entries) }

    func load() async {
        guard entries.isEmpty else { return await refresh() }
        isLoading = true
        errorMessage = nil
        await refresh()
        isLoading = false
    }

    /// Tải lại im lặng (sau khi học thẻ / kiểm tra / đánh dấu đã thuộc).
    func refresh() async {
        do {
            availableLevels = await repository.availableLevels()
            async let words = repository.words(level: level)
            async let summary = repository.summary(level: level)
            entries = try await words
            self.summary = try await summary
            errorMessage = nil
        } catch {
            if entries.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    func isAvailable(_ level: Int) -> Bool { availableLevels.contains(level) }

    func play(_ word: VocabWord) {
        pronunciation.speak(word.hanzi)
    }
}
