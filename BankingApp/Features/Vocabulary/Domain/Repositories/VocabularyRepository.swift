import Foundation

/// Từ vựng HSK và tiến độ học của người dùng đang đăng nhập.
///
/// Đã có API (chỉ đọc): `GET v1/hsk/levels`, `GET v1/hsk/levels/{level}/words`,
/// `GET v1/hsk/levels/{level}/words/{entryNumber}`.
/// Chưa có API ghi tiến độ (lật thẻ, đánh dấu đã thuộc, nộp bài kiểm tra):
/// bản API thật trả `canUpdateProgress = false` và chấm bài kiểm tra ngay trên máy.
protocol VocabularyRepository: Sendable {
    /// Đủ 9 cấp, cấp chưa có từ thì `isAvailable = false`.
    func levels() async throws -> [HSKLevelProgress]
    /// `status = nil`: tất cả. `page` bắt đầu từ 0.
    func words(level: Int, status: VocabStatus?, page: Int, size: Int) async throws -> VocabPage
    /// Chi tiết một từ (Hán Việt, từ loại, cách dùng, ví dụ).
    func word(level: Int, entryNumber: Int) async throws -> VocabEntry

    /// Server đã hỗ trợ ghi tiến độ chưa (ẩn nút "Đánh dấu đã thuộc" nếu chưa).
    var canUpdateProgress: Bool { get }
    /// Bộ thẻ cho một lượt học: từ đang học trước, rồi tới từ mới.
    func flashcards(level: Int, limit: Int) async throws -> [VocabWord]
    func review(wordID: String, result: ReviewResult) async throws -> VocabStatus
    func setStatus(wordID: String, status: VocabStatus) async throws -> VocabStatus

    func lastQuizAttempt(level: Int) async -> QuizAttemptSummary?
    func createQuiz(_ config: QuizConfig) async throws -> Quiz
    func submitQuiz(_ quiz: Quiz, answers: [QuizAnswer]) async throws -> QuizSubmission
}

enum VocabularyError: LocalizedError, Equatable {
    case noWordsInScope
    case notEnoughWords
    case progressNotSupported

    var errorDescription: String? {
        switch self {
        case .noWordsInScope: return "Chưa có từ nào trong phạm vi này. Hãy chọn phạm vi khác."
        case .notEnoughWords: return "Cấp này chưa đủ từ để tạo bài kiểm tra."
        case .progressNotSupported: return "Chưa lưu được tiến độ học. Tính năng sẽ có trong bản cập nhật tới."
        }
    }
}
