import Foundation

/// Từ vựng HSK và tiến độ học của người dùng đang đăng nhập.
/// API dự kiến: `GET v1/vocab/levels/{level}/summary`, `GET v1/vocab/words`,
/// `GET v1/vocab/flashcards`, `POST v1/vocab/reviews`, `PUT v1/vocab/words/{id}/progress`,
/// `POST v1/vocab/quizzes`, `POST v1/vocab/quizzes/{id}/submit`.
protocol VocabularyRepository: Sendable {
    /// Các cấp đã có dữ liệu (hiện tại chỉ HSK 1).
    func availableLevels() async -> [Int]
    func words(level: Int) async throws -> [VocabEntry]
    func summary(level: Int) async throws -> VocabSummary
    /// Bộ thẻ cho một lượt học: từ đến hạn ôn, rồi từ đang học, rồi từ mới.
    /// `wordIDs` khác nil: chỉ lấy đúng các từ đó (ôn lại từ sai).
    func flashcards(level: Int, limit: Int, wordIDs: [String]?) async throws -> [VocabWord]
    func review(wordID: String, result: ReviewResult) async throws -> VocabStatus
    func setStatus(wordID: String, status: VocabStatus) async throws -> VocabStatus

    func lastQuizAttempt(level: Int) async -> QuizAttemptSummary?
    func createQuiz(_ config: QuizConfig) async throws -> Quiz
    func submitQuiz(_ quiz: Quiz, answers: [QuizAnswer]) async throws -> QuizSubmission
}

enum VocabularyError: LocalizedError {
    case noWordsInScope

    var errorDescription: String? {
        switch self {
        case .noWordsInScope: return "Chưa có từ nào trong phạm vi này. Hãy chọn phạm vi khác."
        }
    }
}
