import Foundation

/// Một thanh điệu (`GET v1/tones`).
struct ToneInfo: Identifiable, Hashable, Sendable {
    /// 1…4.
    let number: Int
    /// Âm ví dụ, vd. "mā".
    let pinyin: String
    /// Các mức cao độ từ trái sang phải, 1 = thấp nhất, 5 = cao nhất (vd. [2, 1, 4]).
    let pitch: [Int]
    let description: String
    var audioURL: URL?

    var id: Int { number }
}

struct ToneGuide: Equatable, Sendable {
    let tones: [ToneInfo]
    /// Mẹo biến điệu (vd. 3 + 3 → 2 + 3).
    let sandhiTip: String?
}

/// Một câu luyện nghe (`GET v1/tones/practice`): nghe cả từ, chọn thanh của âm tiết thứ `syllablePosition`.
struct TonePracticeQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let hanzi: String
    let level: Int?
    let entryNumber: Int?
    /// Âm tiết cần nghe, chưa có dấu (vd. "hao").
    let syllable: String
    /// Đếm từ 1.
    let syllablePosition: Int
    let audioURL: URL?
    let correctTone: Int

    /// Chữ Hán của âm tiết cần nghe (nếu số chữ khớp số âm tiết).
    var targetCharacter: String? {
        let characters = Array(hanzi)
        guard syllablePosition >= 1, syllablePosition <= characters.count else { return nil }
        return String(characters[syllablePosition - 1])
    }
}

protocol TonesRepository: Sendable {
    func guide() async throws -> ToneGuide
    /// Một lượt 10 câu ngẫu nhiên.
    func practice() async throws -> [TonePracticeQuestion]
}
