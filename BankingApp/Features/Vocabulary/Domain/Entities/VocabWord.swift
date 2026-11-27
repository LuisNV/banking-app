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
    /// Chiết tự từng chữ (tách bộ phận + cách nhớ).
    var decomposition: [CharacterDecomposition] = []
    var audioURL: URL?
    var hasDetail = true
}

struct HanVietCharacter: Hashable, Sendable {
    let hanzi: String
    let reading: String
    let meaning: String
}

/// Một bộ phận trong chữ, ví dụ 亻 "nhân" (người).
struct DecompositionComponent: Hashable, Sendable {
    let character: String
    var hanViet: String?
    var meaning: String?
}

/// Chiết tự một chữ: bộ phận ghép lại + câu gợi nhớ.
/// Server mới trả `components`/`mnemonicVi`; server cũ chỉ có câu `noteVi`
/// dạng "Trái/phải [亻 (người) + 木 (cây)] Gợi nhớ…" → tách bằng `fromNote`.
struct CharacterDecomposition: Hashable, Sendable {
    let character: String
    /// Âm Hán Việt của chữ ("nhĩ").
    var hanViet: String?
    /// "Trái/phải", "Trên/dưới"…
    var layout: String?
    var components: [DecompositionComponent] = []
    /// Công thức dạng chữ ("亻 (người) + 尔 (ngươi)"), dùng khi không có `components`.
    var formula: String?
    var mnemonic: String?
    /// Ghi chú gốc, hiện nguyên văn khi không có gì khác.
    var note: String?

    /// Từ câu ghi chú kiểu cũ.
    static func fromNote(character: String, note: String) -> CharacterDecomposition {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = parse(trimmed)
        return CharacterDecomposition(
            character: character,
            layout: parts?.layout,
            formula: parts?.formula,
            mnemonic: parts?.mnemonic,
            note: trimmed
        )
    }

    /// Tách "Bố cục [công thức] Gợi nhớ" theo cặp ngoặc vuông ngoài cùng (công thức có thể lồng ngoặc).
    static func parse(_ note: String) -> (layout: String?, formula: String, mnemonic: String?)? {
        guard let open = note.firstIndex(of: "[") else { return nil }
        var depth = 0
        var close: String.Index?
        for index in note[open...].indices {
            switch note[index] {
            case "[": depth += 1
            case "]":
                depth -= 1
                if depth == 0 { close = index }
            default: break
            }
            if close != nil { break }
        }
        guard let close else { return nil }
        let layout = note[..<open].trimmingCharacters(in: .whitespaces)
        let formula = note[note.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        let mnemonic = note[note.index(after: close)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !formula.isEmpty else { return nil }
        return (layout.isEmpty ? nil : layout, formula, mnemonic.isEmpty ? nil : mnemonic)
    }

    /// Dòng gọn cho mặt sau thẻ: "爱 = 爫 + 冖 + 友".
    var compactFormula: String? {
        if !components.isEmpty { return components.map(\.character).joined(separator: " + ") }
        return formula ?? note
    }

    /// Từ cần tô đậm trong câu gợi nhớ: nghĩa của các bộ phận và phần kết luận sau "→".
    var mnemonicHighlights: [String] {
        var words = components.compactMap(\.meaning).filter { !$0.isEmpty }
        if let mnemonic, let arrow = mnemonic.range(of: "→") {
            let conclusion = mnemonic[arrow.upperBound...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
            words += conclusion.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return words.filter { !$0.isEmpty }
    }
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

// MARK: - Thẻ ghi nhớ

/// Lý do thẻ có trong lượt: đến hạn ôn hay từ mới.
enum FlashcardReason: String, Sendable {
    case due = "DUE"
    case new = "NEW"
}

struct Flashcard: Identifiable, Hashable, Sendable {
    let word: VocabWord
    var status: VocabStatus = .notStarted
    /// `nil`: thẻ không đến từ API bộ thẻ (vd. ôn lại từ làm sai).
    var reason: FlashcardReason?

    var id: String { word.id }
}

/// Một lượt học thẻ (`GET v1/hsk/levels/{level}/flashcards`).
struct FlashcardDeck: Equatable, Sendable {
    let cards: [Flashcard]
    /// Tổng số từ đang đến hạn của cả cấp (có thể nhiều hơn số thẻ trong lượt).
    let dueCount: Int
    /// Tổng số từ chưa học còn lại.
    let newCount: Int
    /// Lần đến hạn sớm nhất sắp tới, để báo "quay lại lúc …" khi hết thẻ.
    let nextDueAt: Date?
}
