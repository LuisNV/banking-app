import Foundation

/// Một từ vựng HSK (dữ liệu tĩnh, giống nhau với mọi người dùng).
struct VocabWord: Identifiable, Hashable, Sendable {
    let id: String
    let level: Int
    let topic: String
    let hanzi: String
    let pinyin: String
    let meaning: String
    let partOfSpeech: String
    /// Âm Hán Việt của cả từ, ví dụ "Nhĩ hảo".
    let hanViet: String
    /// Giải thích ngắn theo nghĩa Hán Việt, ví dụ "ngươi tốt → lời chào".
    let hanVietNote: String?
    let characters: [HanVietCharacter]
    let examples: [VocabExample]
    let audioURL: URL?
}

struct HanVietCharacter: Hashable, Sendable {
    let hanzi: String
    let reading: String
    let meaning: String
}

struct VocabExample: Hashable, Sendable {
    let hanzi: String
    let pinyin: String
    let meaning: String
    var note: String?
}

/// Trạng thái học của một từ với người dùng hiện tại.
/// `notStarted` không lưu trên server: từ nào chưa có tiến độ thì là chưa học.
enum VocabStatus: String, CaseIterable, Hashable, Sendable {
    case notStarted = "NEW"
    case learning = "LEARNING"
    case known = "KNOWN"
}

/// Từ kèm trạng thái của người dùng.
struct VocabEntry: Identifiable, Hashable, Sendable {
    let word: VocabWord
    var status: VocabStatus

    var id: String { word.id }
}

struct VocabSummary: Equatable, Sendable {
    let total: Int
    let known: Int
    let learning: Int

    var notStarted: Int { max(total - known - learning, 0) }
    var started: Int { known + learning }

    static let empty = VocabSummary(total: 0, known: 0, learning: 0)
}

/// Kết quả một lần lật thẻ.
enum ReviewResult: String, Sendable {
    case good = "GOOD"
    case again = "AGAIN"
}
