import Foundation

/// Dữ liệu giả cho Từ vựng HSK (USE_MOCK_API = YES): giữ tiến độ trong bộ nhớ,
/// áp dụng quy tắc chuyển trạng thái dự kiến của server (kể cả phần ghi chưa có API).
actor MockVocabularyRepository: VocabularyRepository {
    private struct Progress {
        var status: VocabStatus
        var correctStreak = 0
        var dueAt = Date()
    }

    /// Số lần "Đã nhớ" liên tiếp để một từ thành "Đã thuộc".
    private static let knownStreak = 3
    private static let intervals: [Double] = [1, 3, 7, 14, 30]

    private let allWords: [VocabWord]
    private var progress: [String: Progress]
    private var attempts: [Int: QuizAttemptSummary] = [:]

    init(words: [VocabWord] = MockVocabularyData.hsk1) {
        self.allWords = words
        // Một vài từ đã học sẵn để màn danh sách có đủ 3 trạng thái.
        progress = [
            "hsk1-nihao": Progress(status: .known, correctStreak: 3),
            "hsk1-xiexie": Progress(status: .known, correctStreak: 4),
            "hsk1-baba": Progress(status: .known, correctStreak: 3),
            "hsk1-yi": Progress(status: .known, correctStreak: 3),
            "hsk1-zaijian": Progress(status: .learning, correctStreak: 1),
            "hsk1-mama": Progress(status: .learning),
            "hsk1-jintian": Progress(status: .learning, correctStreak: 2),
        ]
        attempts[1] = QuizAttemptSummary(correct: 7, total: 10, finishedAt: Date().addingTimeInterval(-86_400))
    }

    nonisolated var canUpdateProgress: Bool { true }

    func levels() async throws -> [HSKLevelProgress] {
        try await latency()
        return (1...9).map { level in
            let words = allWords.filter { $0.level == level }
            let statuses = words.map { status(of: $0.id) }
            return HSKLevelProgress(
                level: level,
                title: HSKLevelProgress.defaultTitle(for: level),
                isAvailable: !words.isEmpty,
                totalWords: words.count,
                mastered: statuses.filter { $0 == .known }.count,
                learning: statuses.filter { $0 == .learning }.count
            )
        }
    }

    func words(level: Int, status filter: VocabStatus?, page: Int, size: Int) async throws -> VocabPage {
        try await latency()
        let matching = allWords
            .filter { $0.level == level }
            .map { VocabEntry(word: $0, status: status(of: $0.id)) }
            .filter { filter == nil || $0.status == filter }
        let totalPages = matching.isEmpty ? 0 : (matching.count + size - 1) / size
        let start = page * size
        let items = start < matching.count ? Array(matching[start..<min(start + size, matching.count)]) : []
        return VocabPage(items: items, page: page, totalItems: matching.count, totalPages: totalPages)
    }

    func word(level: Int, entryNumber: Int) async throws -> VocabEntry {
        try await latency()
        guard let word = allWords.first(where: { $0.level == level && $0.entryNumber == entryNumber }) else {
            throw NetworkError.api(code: 1026, httpStatus: 404, message: "Không tìm thấy từ vựng", traceId: nil)
        }
        return VocabEntry(word: word, status: status(of: word.id))
    }

    func wordOfTheDay() async throws -> VocabEntry {
        try await latency()
        // Đổi theo ngày trong năm để mỗi ngày một từ.
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let withDecomposition = allWords.filter { !$0.decomposition.isEmpty }
        let pool = withDecomposition.isEmpty ? allWords : withDecomposition
        guard !pool.isEmpty else { throw VocabularyError.noWordsInScope }
        let word = pool[day % pool.count]
        return VocabEntry(word: word, status: status(of: word.id))
    }

    func flashcards(level: Int, limit: Int) async throws -> FlashcardDeck {
        try await latency()
        let now = Date()
        let levelWords = allWords.filter { $0.level == level }
        let due = levelWords
            .filter { progress[$0.id].map { $0.dueAt <= now } ?? false }
            .sorted { (progress[$0.id]?.dueAt ?? now) < (progress[$1.id]?.dueAt ?? now) }
        let fresh = levelWords.filter { progress[$0.id] == nil }
        let cards = due.prefix(limit).map { Flashcard(word: $0, status: status(of: $0.id), reason: .due) }
            + fresh.prefix(max(limit - min(due.count, limit), 0)).map { Flashcard(word: $0, status: .notStarted, reason: .new) }
        let nextDueAt = progress.values.map(\.dueAt).filter { $0 > now }.min()
        return FlashcardDeck(cards: cards, dueCount: due.count, newCount: fresh.count, nextDueAt: nextDueAt)
    }

    func review(_ word: VocabWord, result: ReviewResult) async throws -> VocabStatus {
        try await review(wordID: word.id, result: result)
    }

    func setStatus(_ word: VocabWord, status: VocabStatus) async throws -> VocabStatus {
        try await setStatus(wordID: word.id, status: status)
    }

    private func review(wordID: String, result: ReviewResult) async throws -> VocabStatus {
        var item = progress[wordID] ?? Progress(status: .learning)
        switch result {
        case .good:
            item.correctStreak += 1
            if item.correctStreak >= Self.knownStreak { item.status = .known }
            let index = min(item.correctStreak - 1, Self.intervals.count - 1)
            item.dueAt = Date().addingTimeInterval(Self.intervals[index] * 86_400)
        case .again:
            item.correctStreak = 0
            item.status = .learning
            item.dueAt = Date()
        }
        progress[wordID] = item
        return item.status
    }

    private func setStatus(wordID: String, status: VocabStatus) async throws -> VocabStatus {
        switch status {
        case .notStarted:
            progress[wordID] = nil
        case .learning:
            progress[wordID] = Progress(status: .learning)
        case .known:
            progress[wordID] = Progress(
                status: .known,
                correctStreak: Self.knownStreak,
                dueAt: Date().addingTimeInterval(7 * 86_400)
            )
        }
        return status
    }

    func lastQuizAttempt(level: Int) async -> QuizAttemptSummary? {
        attempts[level]
    }

    func createQuiz(_ config: QuizConfig) async throws -> Quiz {
        try await latency()
        let levelWords = allWords.filter { $0.level == config.level }
        let pool: [VocabWord]
        switch config.scope {
        case .all: pool = levelWords
        case .learning: pool = levelWords.filter { status(of: $0.id) == .learning }
        case .known: pool = levelWords.filter { status(of: $0.id) == .known }
        }
        return try QuizGenerator.make(config, pool: pool, levelWords: levelWords)
    }

    func submitQuiz(_ quiz: Quiz, answers: [QuizAnswer]) async throws -> QuizSubmission {
        try await latency()
        var statuses: [String: VocabStatus] = [:]
        for question in quiz.questions {
            let isCorrect = answers.first { $0.questionID == question.id }?.optionID == question.correctOptionID
            let current = status(of: question.word.id)
            if !isCorrect {
                statuses[question.word.id] = try await review(wordID: question.word.id, result: .again)
            } else if current == .notStarted {
                // Đúng một từ chưa học: có thể đoán mò, chỉ chuyển sang "Đang học".
                statuses[question.word.id] = try await setStatus(wordID: question.word.id, status: .learning)
            } else {
                statuses[question.word.id] = try await review(wordID: question.word.id, result: .good)
            }
        }
        let level = quiz.questions.first?.word.level ?? 1
        let previous = attempts[level]
        let correct = QuizGenerator.correctCount(quiz, answers: answers)
        attempts[level] = QuizAttemptSummary(correct: correct, total: quiz.questions.count, finishedAt: Date())
        return QuizSubmission(
            correct: correct,
            total: quiz.questions.count,
            previousPercent: previous.map { $0.total > 0 ? $0.correct * 100 / $0.total : 0 },
            statuses: statuses
        )
    }

    // MARK: Helpers

    private func status(of wordID: String) -> VocabStatus {
        progress[wordID]?.status ?? .notStarted
    }

    private func latency() async throws {
        try await Task.sleep(for: .milliseconds(250))
    }
}
