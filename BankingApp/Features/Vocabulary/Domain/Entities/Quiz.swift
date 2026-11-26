import Foundation

enum QuizQuestionType: String, CaseIterable, Hashable, Sendable {
    case hanziToMeaning = "HANZI_TO_MEANING"
    case meaningToHanzi = "MEANING_TO_HANZI"
    case audioToHanzi = "AUDIO_TO_HANZI"
}

enum QuizScope: Hashable, Sendable {
    case all
    case learning
    case known
    case topic(String)
}

struct QuizConfig: Hashable, Sendable {
    var level = 1
    var scope: QuizScope = .all
    var questionCount = 10
    var types: Set<QuizQuestionType> = Set(QuizQuestionType.allCases)
}

struct QuizOption: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
}

struct QuizQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let type: QuizQuestionType
    let word: VocabWord
    let options: [QuizOption]
    let correctOptionID: String

    /// Đáp án là chữ Hán (Nghĩa → Hán, Nghe → Hán) hay là nghĩa tiếng Việt.
    var optionsAreHanzi: Bool { type != .hanziToMeaning }
}

struct Quiz: Identifiable, Hashable, Sendable {
    let id: String
    let questions: [QuizQuestion]
}

struct QuizAnswer: Hashable, Sendable {
    let questionID: String
    let optionID: String
    let elapsed: TimeInterval
}

/// Kết quả chấm của server sau khi nộp bài.
struct QuizSubmission: Equatable, Sendable {
    let correct: Int
    let total: Int
    /// Điểm phần trăm lần làm trước (cùng cấp), để so sánh.
    let previousPercent: Int?
    /// Trạng thái mới của các từ trong bài.
    let statuses: [String: VocabStatus]
}

/// Lần kiểm tra gần nhất, hiện ở màn thiết lập.
struct QuizAttemptSummary: Equatable, Sendable {
    let correct: Int
    let total: Int
    let finishedAt: Date
}
