import Foundation

/// Một từ vựng HSK (dữ liệu tĩnh, giống nhau với mọi người dùng).
/// Từ lấy từ danh sách chỉ có thông tin cơ bản; các trường chi tiết có sau khi gọi API chi tiết (`hasDetail`).
struct VocabWord: Identifiable, Hashable, Sendable {
    let id: String
    let level: Int
    /// Số thứ tự trong giáo trình, dùng để gọi API chi tiết.
    var entryNumber: Int = 0
    var topic: String?
    let hanzi: String
    let pinyin: String
    let meaning: String
    /// Từ loại: "Danh từ", "Động từ", "Cụm từ"…
    var partOfSpeech: String?
    /// Âm Hán Việt của cả từ, ví dụ "nhĩ hảo".
    var hanViet: String?
    /// Giải thích theo nghĩa Hán Việt.
    var hanVietNote: String?
    /// Ghi chú cách dùng.
    var usageNote: String?
    var characters: [HanVietCharacter] = []
    var examples: [VocabExample] = []
    var audioURL: URL?
    var hasDetail = true
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
/// Server không lưu `notStarted`: từ nào chưa có dòng tiến độ thì là chưa học.
enum VocabStatus: String, CaseIterable, Hashable, Sendable {
    case notStarted = "NOT_STARTED"
    case learning = "LEARNING"
    case known = "MASTERED"
}

/// Từ kèm trạng thái của người dùng.
struct VocabEntry: Identifiable, Hashable, Sendable {
    var word: VocabWord
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

/// Một cấp HSK kèm tiến độ của người dùng (`GET v1/hsk/levels`).
struct HSKLevelProgress: Identifiable, Hashable, Sendable {
    let level: Int
    /// "Sơ cấp", "Trung cấp", "Cao cấp".
    let title: String
    /// `false`: cấp chưa có từ, hiện khoá.
    let isAvailable: Bool
    let totalWords: Int
    let mastered: Int
    let learning: Int

    var id: Int { level }
    var summary: VocabSummary { VocabSummary(total: totalWords, known: mastered, learning: learning) }

    static func defaultTitle(for level: Int) -> String {
        switch level {
        case ...3: return "Sơ cấp"
        case 4...6: return "Trung cấp"
        default: return "Cao cấp"
        }
    }
}

/// Một trang danh sách từ (`GET v1/hsk/levels/{level}/words`).
struct VocabPage: Equatable, Sendable {
    let items: [VocabEntry]
    let page: Int
    let totalItems: Int
    let totalPages: Int

    var hasMore: Bool { page + 1 < totalPages }
}

/// Kết quả một lần lật thẻ (giá trị gửi lên `POST v1/hsk/reviews`).
enum ReviewResult: String, Sendable {
    case good = "REMEMBERED"
    case again = "FORGOT"
}
