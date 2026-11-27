import Foundation

/// Một âm trong bảng (thanh mẫu hoặc vận mẫu), kèm chữ ví dụ và mẹo phát âm.
struct PinyinSound: Identifiable, Hashable, Sendable {
    /// "zh", "ong"…
    let symbol: String
    /// Cách đọc của chữ ví dụ, có thanh điệu ("zhōng").
    var examplePinyin: String?
    var exampleHanzi: String?
    var meaning: String?
    /// Hướng dẫn đặt lưỡi / so sánh với tiếng Việt.
    var tip: String?
    var audioURL: URL?

    var id: String { symbol }
}

struct PinyinGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let sounds: [PinyinSound]
}

/// Một cách ghép: thanh mẫu + vận mẫu → âm tiết chưa gắn thanh ("zh" + "ong" → "zhong").
struct PinyinCombination: Identifiable, Hashable, Sendable {
    /// Rỗng: âm tiết không có thanh mẫu (vd. "a", "er").
    let initial: String
    let final: String
    let syllable: String

    var id: String { "\(initial)+\(final)" }
}

struct PinyinChart: Equatable, Sendable {
    let initials: [PinyinGroup]
    let finals: [PinyinGroup]
    let combinations: [PinyinCombination]
}

/// `GET v1/pinyin/chart`: cả 3 tab trong một lần gọi.
protocol PinyinRepository: Sendable {
    func chart() async throws -> PinyinChart
}
