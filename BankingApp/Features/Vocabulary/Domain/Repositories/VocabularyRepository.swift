import Foundation

/// Từ vựng HSK và tiến độ học của người dùng đang đăng nhập.
///
/// API: `GET v1/hsk/levels`, `GET v1/hsk/levels/{level}/words`,
/// `GET v1/hsk/levels/{level}/words/{entryNumber}`, `GET v1/hsk/levels/{level}/flashcards`,
/// `POST v1/hsk/reviews` (kết quả lật thẻ),
/// `PUT v1/hsk/levels/{level}/words/{entryNumber}/progress` (tự đánh dấu).
/// Server chưa có API kiểm tra: đề được tạo và chấm trên máy, kết quả gửi lên như các lần lật thẻ.
protocol VocabularyRepository: Sendable {
    /// Đủ 9 cấp, cấp chưa có từ thì `isAvailable = false`.
    func levels() async throws -> [HSKLevelProgress]
    /// `status = nil`: tất cả. `page` bắt đầu từ 0.
    func words(level: Int, status: VocabStatus?, page: Int, size: Int) async throws -> VocabPage
    /// Chi tiết một từ (Hán Việt, từ loại, cách dùng, ví dụ).
    func word(level: Int, entryNumber: Int) async throws -> VocabEntry
    /// Từ của ngày (`GET v1/hsk/word-of-the-day`), có sẵn chiết tự.
    func wordOfTheDay() async throws -> VocabEntry

    /// Có ghi được tiến độ không (ẩn nút "Đánh dấu đã thuộc" nếu không).
    var canUpdateProgress: Bool { get }
    /// Bộ thẻ cho một lượt học: từ đến hạn ôn (quá hạn lâu nhất trước), còn chỗ thì bù từ mới.
    func flashcards(level: Int, limit: Int) async throws -> FlashcardDeck
    /// Ghi kết quả lật thẻ, trả trạng thái mới của từ.
    func review(_ word: VocabWord, result: ReviewResult) async throws -> VocabStatus
    /// Tự đánh dấu (Đã thuộc / Đang học / Chưa học), trả trạng thái mới.
    func setStatus(_ word: VocabWord, status: VocabStatus) async throws -> VocabStatus

    func lastQuizAttempt(level: Int) async -> QuizAttemptSummary?
    func createQuiz(_ config: QuizConfig) async throws -> Quiz
    func submitQuiz(_ quiz: Quiz, answers: [QuizAnswer]) async throws -> QuizSubmission
}

enum VocabularyError: LocalizedError, Equatable {
    case noWordsInScope
    case notEnoughWords

    var errorDescription: String? {
        switch self {
        case .noWordsInScope: return "Chưa có từ nào trong phạm vi này. Hãy chọn phạm vi khác."
        case .notEnoughWords: return "Cấp này chưa đủ từ để tạo bài kiểm tra."
        }
    }
}
