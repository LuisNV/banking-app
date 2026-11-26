import Factory
import Foundation
import Observation

@Observable
@MainActor
final class VocabularyDetailViewModel {
    private(set) var entries: [VocabEntry]
    private(set) var index: Int
    private(set) var isUpdating = false
    private(set) var isLoadingDetail = false
    private(set) var detailError: String?
    var errorMessage: String?

    private let repository: any VocabularyRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        entries: [VocabEntry],
        index: Int,
        repository: any VocabularyRepository = Container.shared.vocabularyRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.entries = entries
        self.index = min(max(index, 0), max(entries.count - 1, 0))
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var entry: VocabEntry { entries[index] }
    var word: VocabWord { entry.word }
    var positionText: String { "HSK \(word.level) · \(index + 1)/\(entries.count)" }
    var canGoPrevious: Bool { index > 0 }
    var canGoNext: Bool { index < entries.count - 1 }
    var canUpdateProgress: Bool { repository.canUpdateProgress }

    func previous() { if canGoPrevious { index -= 1 } }
    func next() { if canGoNext { index += 1 } }

    /// Từ trong danh sách chỉ có thông tin cơ bản: tải chi tiết (Hán Việt, cách dùng, ví dụ) khi mở.
    func loadDetailIfNeeded() async {
        let current = index
        guard !entries[current].word.hasDetail else { return }
        isLoadingDetail = true
        detailError = nil
        do {
            let detail = try await repository.word(level: word.level, entryNumber: word.entryNumber)
            entries[current] = detail
        } catch {
            if current == index { detailError = error.localizedDescription }
        }
        if current == index { isLoadingDetail = false }
    }

    func play() {
        pronunciation.play(url: word.audioURL, fallbackText: word.hanzi, slow: false)
    }

    func play(_ example: VocabExample) {
        pronunciation.speak(example.hanzi)
    }

    /// Đã thuộc ↔ học lại.
    func toggleKnown() async {
        let target: VocabStatus = entry.status == .known ? .learning : .known
        let current = index
        isUpdating = true
        defer { isUpdating = false }
        do {
            let status = try await repository.setStatus(wordID: word.id, status: target)
            entries[current].status = status
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
