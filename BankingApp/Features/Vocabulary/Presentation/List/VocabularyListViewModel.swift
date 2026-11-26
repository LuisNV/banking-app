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

        /// Giá trị `status` gửi lên API (`nil` = tất cả).
        var status: VocabStatus? {
            switch self {
            case .all: return nil
            case .notStarted: return .notStarted
            case .learning: return .learning
            case .known: return .known
            }
        }
    }

    static let pageSize = 50

    private(set) var levels: [HSKLevelProgress] = []
    private(set) var selectedLevel = 1
    private(set) var filter: Filter = .all
    private(set) var entries: [VocabEntry] = []
    private(set) var totalItems = 0
    private(set) var isLoadingLevels = false
    private(set) var isLoadingWords = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var loadMoreFailed = false
    private var page = -1
    private var totalPages = 0
    /// Tăng mỗi lần đổi cấp/bộ lọc để bỏ kết quả của lượt tải cũ về muộn.
    private var generation = 0

    private let repository: any VocabularyRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        repository: any VocabularyRepository = Container.shared.vocabularyRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var currentLevel: HSKLevelProgress? { levels.first { $0.level == selectedLevel } }
    var summary: VocabSummary { currentLevel?.summary ?? .empty }
    var levelTitle: String { "HSK \(selectedLevel) · \(currentLevel?.title ?? HSKLevelProgress.defaultTitle(for: selectedLevel))" }
    var hasMore: Bool { page + 1 < totalPages }
    var canUpdateProgress: Bool { repository.canUpdateProgress }
    /// Chưa có gì để hiện (lần tải đầu hoặc lỗi lần đầu).
    var isEmptyState: Bool { levels.isEmpty }

    func load() async {
        guard levels.isEmpty else { return }
        isLoadingLevels = true
        errorMessage = nil
        do {
            levels = try await repository.levels()
            if currentLevel?.isAvailable != true, let first = levels.first(where: \.isAvailable) {
                selectedLevel = first.level
            }
            isLoadingLevels = false
            await reloadWords()
        } catch {
            isLoadingLevels = false
            errorMessage = error.localizedDescription
        }
    }

    func retry() async {
        if levels.isEmpty {
            await load()
        } else {
            await reloadWords()
        }
    }

    func select(level: Int) async {
        guard level != selectedLevel, levels.first(where: { $0.level == level })?.isAvailable == true else { return }
        selectedLevel = level
        await reloadWords()
    }

    func setFilter(_ newFilter: Filter) async {
        guard newFilter != filter else { return }
        filter = newFilter
        await reloadWords()
    }

    /// Gọi khi một dòng hiện ra: gần cuối danh sách thì tải trang tiếp.
    func loadMoreIfNeeded(after entry: VocabEntry) async {
        guard hasMore, !isLoadingMore, !isLoadingWords, !loadMoreFailed else { return }
        guard let index = entries.firstIndex(of: entry), index >= entries.count - 10 else { return }
        await loadNextPage()
    }

    func retryLoadMore() async {
        loadMoreFailed = false
        await loadNextPage()
    }

    /// Cập nhật số liệu sau khi học thẻ / kiểm tra / đánh dấu (không làm mất vị trí cuộn).
    func refreshAfterLearning() async {
        guard !levels.isEmpty else { return }
        if let updated = try? await repository.levels() { levels = updated }
        guard canUpdateProgress else { return }
        // Trạng thái từ có thể đã đổi: tải lại các trang đã xem.
        let loadedPages = page + 1
        let currentGeneration = generation
        var refreshed: [VocabEntry] = []
        for index in 0..<max(loadedPages, 1) {
            guard let result = try? await repository.words(level: selectedLevel, status: filter.status, page: index, size: Self.pageSize),
                  currentGeneration == generation else { return }
            refreshed += result.items
            totalItems = result.totalItems
            totalPages = result.totalPages
        }
        entries = refreshed
    }

    func play(_ word: VocabWord) {
        pronunciation.play(url: word.audioURL, fallbackText: word.hanzi, slow: false)
    }

    // MARK: Private

    private func reloadWords() async {
        generation += 1
        let currentGeneration = generation
        isLoadingWords = true
        loadMoreFailed = false
        errorMessage = nil
        do {
            let result = try await repository.words(level: selectedLevel, status: filter.status, page: 0, size: Self.pageSize)
            guard currentGeneration == generation else { return }
            entries = result.items
            page = result.page
            totalPages = result.totalPages
            totalItems = result.totalItems
        } catch {
            guard currentGeneration == generation else { return }
            entries = []
            totalItems = 0
            page = -1
            totalPages = 0
            errorMessage = error.localizedDescription
        }
        isLoadingWords = false
    }

    private func loadNextPage() async {
        let currentGeneration = generation
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await repository.words(level: selectedLevel, status: filter.status, page: page + 1, size: Self.pageSize)
            guard currentGeneration == generation else { return }
            let known = Set(entries.map(\.id))
            entries += result.items.filter { !known.contains($0.id) }
            page = result.page
            totalPages = result.totalPages
            totalItems = result.totalItems
        } catch {
            guard currentGeneration == generation else { return }
            loadMoreFailed = true
        }
    }
}
