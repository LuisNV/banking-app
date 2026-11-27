import Foundation

/// Một bộ thủ (`GET v1/radicals`).
struct Radical: Identifiable, Hashable, Sendable {
    struct Example: Hashable, Sendable {
        let hanzi: String
        let hanViet: String?
        let meaning: String?
    }

    /// Số thứ tự Khang Hy (1…214).
    let number: Int
    /// Dạng hiển thị (vd. 氵).
    let symbol: String
    /// Dạng gốc Khang Hy (vd. 水).
    let canonical: String
    let forms: [String]
    let hanViet: String
    /// Tên gọi khác (vd. "Ba chấm thủy").
    let alias: String?
    let meaning: String
    /// Số nét của dạng hiển thị.
    let strokes: Int
    let canonicalStrokes: Int?
    let isCommon: Bool
    let description: String?
    let examples: [Example]

    var id: Int { number }
    var isVariant: Bool { symbol != canonical }
}

/// Bộ lọc số nét gửi lên server: `all`, `2`, `3`, `4`, `5+`.
enum RadicalStrokeFilter: String, CaseIterable, Hashable, Sendable {
    case all
    case two = "2"
    case three = "3"
    case four = "4"
    case fivePlus = "5+"

    var title: String {
        switch self {
        case .all: return "Tất cả"
        case .two: return "2 nét"
        case .three: return "3 nét"
        case .four: return "4 nét"
        case .fivePlus: return "5+ nét"
        }
    }
}

struct RadicalQuery: Hashable, Sendable {
    var commonOnly: Bool
    var search: String = ""
    var strokes: RadicalStrokeFilter = .all
}

struct RadicalList: Equatable, Sendable {
    let total: Int
    let items: [Radical]
}

protocol RadicalsRepository: Sendable {
    func radicals(_ query: RadicalQuery) async throws -> RadicalList
}
