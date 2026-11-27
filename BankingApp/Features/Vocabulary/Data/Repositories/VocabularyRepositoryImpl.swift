import Foundation

/// Từ vựng HSK từ API thật. Server chưa có API kiểm tra nên đề được tạo và chấm trên máy;
/// kết quả từng câu gửi lên `POST v1/hsk/reviews` như lật thẻ (sai = FORGOT, đúng = REMEMBERED).
/// Điểm "lần trước" chỉ giữ trong bộ nhớ.
actor VocabularyRepositoryImpl: VocabularyRepository {
    /// Server cho tối đa 100 từ một trang và 100 thẻ một lần ghi.
    private static let maxPageSize = 100
    private static let maxReviewItems = 100

    private let remote: any HSKVocabularyRemoteDataSource
    private let audioBaseURL: URL
    /// Toàn bộ từ của một cấp (để tạo đề kiểm tra), tải một lần cho mỗi lượt mở app.
    private var levelWordsCache: [Int: [VocabEntry]] = [:]
    private var attempts: [Int: QuizAttemptSummary] = [:]

    init(remote: any HSKVocabularyRemoteDataSource, apiBaseURL: URL) {
        self.remote = remote
        self.audioBaseURL = HSKVocabularyMapping.serverOrigin(of: apiBaseURL)
    }

    nonisolated var canUpdateProgress: Bool { true }

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

    func wordOfTheDay() async throws -> VocabEntry {
        try await remote.wordOfTheDay().toDomain(audioBaseURL: audioBaseURL)
    }

    func flashcards(level: Int, limit: Int) async throws -> FlashcardDeck {
        // Server cho 1–50 thẻ một lượt.
        try await remote.flashcards(level: level, size: min(max(limit, 1), 50)).toDomain(audioBaseURL: audioBaseURL)
    }

    func review(_ word: VocabWord, result: ReviewResult) async throws -> VocabStatus {
        let statuses = try await sendReviews([(word, result)])
        return statuses[word.id] ?? .learning
    }

    func setStatus(_ word: VocabWord, status: VocabStatus) async throws -> VocabStatus {
        let response = try await remote.putProgress(
            level: word.level,
            entryNumber: word.entryNumber,
            body: HSKProgressPutDTO(status: status.rawValue)
        )
        levelWordsCache[word.level] = nil
        return response.word.domainStatus
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
        // Câu chưa trả lời thì bỏ qua; mỗi câu đã trả lời ghi như một lần lật thẻ.
        let reviews: [(VocabWord, ReviewResult)] = quiz.questions.compactMap { question in
            guard let answer = answers.first(where: { $0.questionID == question.id }) else { return nil }
            return (question.word, answer.optionID == question.correctOptionID ? .good : .again)
        }
        // Không gửi được thì vẫn trả điểm (chấm trên máy), chỉ là tiến độ chưa cập nhật.
        let statuses = (try? await sendReviews(reviews)) ?? [:]
        let previous = attempts[level]
        attempts[level] = QuizAttemptSummary(correct: correct, total: quiz.questions.count, finishedAt: Date())
        return QuizSubmission(
            correct: correct,
            total: quiz.questions.count,
            previousPercent: previous.map { $0.total > 0 ? $0.correct * 100 / $0.total : 0 },
            statuses: statuses
        )
    }

    /// Gửi kết quả theo lô ≤ 100 thẻ, trả trạng thái cuối của từng từ.
    private func sendReviews(_ reviews: [(VocabWord, ReviewResult)]) async throws -> [String: VocabStatus] {
        var statuses: [String: VocabStatus] = [:]
        var start = 0
        while start < reviews.count {
            let chunk = reviews[start..<min(start + Self.maxReviewItems, reviews.count)]
            let body = HSKReviewRequestDTO(items: chunk.map {
                .init(level: $0.0.level, entryNumber: $0.0.entryNumber, result: $0.1.rawValue)
            })
            let response = try await remote.reviews(body)
            for item in response.items {
                statuses[item.wordID] = item.domainStatus
                levelWordsCache[item.level] = nil
            }
            start += Self.maxReviewItems
        }
        return statuses
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
