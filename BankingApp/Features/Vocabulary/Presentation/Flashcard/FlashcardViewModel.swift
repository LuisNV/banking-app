import Factory
import Foundation
import Observation

@Observable
@MainActor
final class FlashcardViewModel {
    let source: FlashcardSource
    static let deckSize = 20

    private(set) var cards: [Flashcard] = []
    /// Lần đến hạn sớm nhất sắp tới (khi lượt rỗng: "quay lại lúc …").
    private(set) var nextDueAt: Date?
    /// Tổng số từ đến hạn của cả cấp lúc bắt đầu lượt.
    private(set) var dueCount = 0
    private(set) var index = 0
    private(set) var goodCount = 0
    private(set) var againCount = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var isFlipped = false

    private let repository: any VocabularyRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        source: FlashcardSource,
        repository: any VocabularyRepository = Container.shared.vocabularyRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.source = source
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var savesProgress: Bool { repository.canUpdateProgress }
    /// Lượt rỗng: báo khi nào có từ đến hạn ôn tiếp (giờ địa phương).
    var emptyMessage: String {
        guard let nextDueAt else { return "Bạn đã học hết các từ của cấp này." }
        let calendar = Calendar.current
        let time = nextDueAt.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(nextDueAt) {
            return "Bạn đã ôn xong. Quay lại lúc \(time) hôm nay nhé!"
        }
        if calendar.isDateInTomorrow(nextDueAt) {
            return "Bạn đã ôn xong. Quay lại lúc \(time) ngày mai nhé!"
        }
        return "Bạn đã ôn xong. Quay lại vào \(nextDueAt.formatted(date: .abbreviated, time: .shortened)) nhé!"
    }

    var currentCard: Flashcard? { index < cards.count ? cards[index] : nil }
    var current: VocabWord? { currentCard?.word }
    var isFinished: Bool { !cards.isEmpty && index >= cards.count }
    var isEmpty: Bool { !isLoading && cards.isEmpty && errorMessage == nil }
    var progress: Double { cards.isEmpty ? 0 : Double(index) / Double(cards.count) }
    var positionText: String { "\(min(index + 1, cards.count))/\(cards.count)" }
    /// Số thẻ còn lại phía sau thẻ hiện tại (vẽ xấp thẻ).
    var remainingBehind: Int { max(cards.count - index - 1, 0) }

    func load() async {
        guard cards.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            switch source {
            case .level(let level):
                let deck = try await repository.flashcards(level: level, limit: Self.deckSize)
                cards = deck.cards
                nextDueAt = deck.nextDueAt
                dueCount = deck.dueCount
            case .words(let words):
                cards = words.map { Flashcard(word: $0) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func flip() { isFlipped.toggle() }

    func play() {
        guard let current else { return }
        pronunciation.play(url: current.audioURL, fallbackText: current.hanzi, slow: false)
    }

    /// Ghi kết quả rồi sang thẻ tiếp (giao diện đổi ngay, lưu chạy nền).
    func answer(_ result: ReviewResult) {
        guard let current else { return }
        switch result {
        case .good: goodCount += 1
        case .again: againCount += 1
        }
        isFlipped = false
        index += 1
        Task { [repository] in _ = try? await repository.review(current, result: result) }
    }

    func restart() {
        cards = []
        index = 0
        goodCount = 0
        againCount = 0
        isFlipped = false
        Task { await load() }
    }
}
