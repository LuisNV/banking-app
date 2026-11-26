import Foundation

/// Từ vựng HSK từ API thật. Server mới có API đọc; phần ghi tiến độ (lật thẻ, đánh dấu, nộp bài)
/// chưa có nên: lật thẻ không lưu, bài kiểm tra tạo và chấm trên máy, điểm lần trước giữ trong bộ nhớ.
actor VocabularyRepositoryImpl: VocabularyRepository {
    /// Server cho tối đa 100 từ một trang.
    private static let maxPageSize = 100

    private let remote: any HSKVocabularyRemoteDataSource
    private let audioBaseURL: URL
    /// Toàn bộ từ của một cấp (để tạo đề kiểm tra), tải một lần cho mỗi lượt mở app.
    private var levelWordsCache: [Int: [VocabEntry]] = [:]
    private var attempts: [Int: QuizAttemptSummary] = [:]

    init(remote: any HSKVocabularyRemoteDataSource, apiBaseURL: URL) {
        self.remote = remote
        self.audioBaseURL = HSKVocabularyMapping.serverOrigin(of: apiBaseURL)
    }

    nonisolated var canUpdateProgress: Bool { false }

    func levels() async throws -> [HSKLevelProgress] {
        try await remote.levels().map { $0.toDomain() }.sorted { $0.level < $1.level }
    }

    func words(level: Int, status: VocabStatus?, page: Int, size: Int) async throws -> VocabPage {
        let dto = try await remote.words(
            level: level,
            status: HSKVocabularyMapping.apiValue(status),
            page: page,
            size: min(max(size, 1), Self.maxPageSize)
        )
        return dto.toDomain(level: level, audioBaseURL: audioBaseURL)
    }

    func word(level: Int, entryNumber: Int) async throws -> VocabEntry {
        try await remote.word(level: level, entryNumber: entryNumber).toDomain(audioBaseURL: audioBaseURL)
    }

    func flashcards(level: Int, limit: Int) async throws -> [VocabWord] {
        // Đang học trước, thiếu thì thêm từ mới theo thứ tự giáo trình.
        let learning = try await words(level: level, status: .learning, page: 0, size: limit).items
        var deck = learning.map(\.word)
        if deck.count < limit {
            let fresh = try await words(level: level, status: .notStarted, page: 0, size: limit - deck.count).items
            deck += fresh.map(\.word)
        }
        return deck
    }

    func review(wordID: String, result: ReviewResult) async throws -> VocabStatus {
        throw VocabularyError.progressNotSupported
    }

    func setStatus(wordID: String, status: VocabStatus) async throws -> VocabStatus {
        throw VocabularyError.progressNotSupported
    }

    func lastQuizAttempt(level: Int) async -> QuizAttemptSummary? {
        attempts[level]
    }

    func createQuiz(_ config: QuizConfig) async throws -> Quiz {
        let entries = try await allWords(level: config.level)
        let pool: [VocabEntry]
        switch config.scope {
        case .all: pool = entries
        case .learning: pool = entries.filter { $0.status == .learning }
        case .known: pool = entries.filter { $0.status == .known }
        }
        return try QuizGenerator.make(config, pool: pool.map(\.word), levelWords: entries.map(\.word))
    }

    func submitQuiz(_ quiz: Quiz, answers: [QuizAnswer]) async throws -> QuizSubmission {
        let level = quiz.questions.first?.word.level ?? 1
        let correct = QuizGenerator.correctCount(quiz, answers: answers)
        let previous = attempts[level]
        attempts[level] = QuizAttemptSummary(correct: correct, total: quiz.questions.count, finishedAt: Date())
        return QuizSubmission(
            correct: correct,
            total: quiz.questions.count,
            previousPercent: previous.map { $0.total > 0 ? $0.correct * 100 / $0.total : 0 },
            statuses: [:]
        )
    }

    /// Tải hết các trang của một cấp (HSK 1 = 300 từ → 3 lần gọi).
    private func allWords(level: Int) async throws -> [VocabEntry] {
        if let cached = levelWordsCache[level] { return cached }
        var result: [VocabEntry] = []
        var page = 0
        while true {
            let current = try await words(level: level, status: nil, page: page, size: Self.maxPageSize)
            result += current.items
            guard current.hasMore else { break }
            page += 1
        }
        levelWordsCache[level] = result
        return result
    }
}
