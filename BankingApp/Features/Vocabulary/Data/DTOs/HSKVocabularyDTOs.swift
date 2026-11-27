import Foundation

struct HSKLevelDTO: Decodable, Equatable {
    let level: Int
    let title: String?
    let available: Bool
    let totalWords: Int
    let mastered: Int
    let learning: Int
    let notStarted: Int?

    func toDomain() -> HSKLevelProgress {
        HSKLevelProgress(
            level: level,
            title: title ?? HSKLevelProgress.defaultTitle(for: level),
            isAvailable: available && totalWords > 0,
            totalWords: totalWords,
            mastered: mastered,
            learning: learning
        )
    }
}

struct HSKWordPageDTO: Decodable, Equatable {
    let items: [HSKWordItemDTO]
    let page: Int
    let size: Int
    let totalItems: Int
    let totalPages: Int

    func toDomain(level: Int, audioBaseURL: URL) -> VocabPage {
        VocabPage(
            items: items.map { $0.toDomain(level: level, audioBaseURL: audioBaseURL) },
            page: page,
            totalItems: totalItems,
            totalPages: totalPages
        )
    }
}

struct HSKWordItemDTO: Decodable, Equatable {
    let entryNumber: Int
    let hanzi: String
    let pinyin: String
    let meaningVi: String
    let audioUrl: String?
    let status: String?

    func toDomain(level: Int, audioBaseURL: URL) -> VocabEntry {
        VocabEntry(
            word: VocabWord(
                id: HSKVocabularyMapping.wordID(level: level, entryNumber: entryNumber),
                level: level,
                entryNumber: entryNumber,
                hanzi: hanzi,
                pinyin: pinyin,
                meaning: meaningVi,
                audioURL: HSKVocabularyMapping.audioURL(audioUrl, base: audioBaseURL),
                hasDetail: false
            ),
            status: HSKVocabularyMapping.status(status)
        )
    }
}

struct HSKWordDetailDTO: Decodable, Equatable {
    let entryNumber: Int
    let level: Int
    let hanzi: String
    let pinyin: String
    let meaningVi: String
    let audioUrl: String?
    let status: String?
    let hanViet: String?
    let hanVietNote: String?
    let wordType: String?
    let usageNote: String?
    let examples: [HSKExampleDTO]?
    let decomposition: [HSKDecompositionDTO]?

    func toDomain(audioBaseURL: URL) -> VocabEntry {
        VocabEntry(
            word: VocabWord(
                id: HSKVocabularyMapping.wordID(level: level, entryNumber: entryNumber),
                level: level,
                entryNumber: entryNumber,
                hanzi: hanzi,
                pinyin: pinyin,
                meaning: meaningVi,
                partOfSpeech: wordType.nonEmpty,
                hanViet: hanViet.nonEmpty,
                hanVietNote: hanVietNote.nonEmpty,
                usageNote: usageNote.nonEmpty,
                examples: (examples ?? []).map {
                    VocabExample(hanzi: $0.sentenceZh, pinyin: $0.pinyin ?? "", meaning: $0.translationVi ?? "", note: $0.note.nonEmpty)
                },
                decomposition: HSKDecompositionDTO.toDomain(decomposition),
                audioURL: HSKVocabularyMapping.audioURL(audioUrl, base: audioBaseURL),
                hasDetail: true
            ),
            status: HSKVocabularyMapping.status(status)
        )
    }
}

struct HSKDecompositionDTO: Decodable, Equatable {
    let character: String
    let noteVi: String?

    /// Bỏ chữ không có ghi chú.
    static func toDomain(_ items: [HSKDecompositionDTO]?) -> [CharacterDecomposition] {
        (items ?? []).compactMap { item in
            guard let note = item.noteVi.nonEmpty else { return nil }
            return CharacterDecomposition(character: item.character, note: note)
        }
    }
}

struct HSKExampleDTO: Decodable, Equatable {
    let sentenceZh: String
    let pinyin: String?
    let translationVi: String?
    let note: String?
}

enum HSKVocabularyMapping {
    static func wordID(level: Int, entryNumber: Int) -> String { "hsk\(level)-\(entryNumber)" }

    static func status(_ raw: String?) -> VocabStatus {
        raw.flatMap(VocabStatus.init(rawValue:)) ?? .notStarted
    }

    static func apiValue(_ status: VocabStatus?) -> String? { status?.rawValue }

    /// `audioUrl` là đường dẫn tương đối tính từ gốc server ("/audio/hsk/..."), không cần token.
    static func audioURL(_ path: String?, base: URL) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let absolute = URL(string: path), absolute.scheme != nil { return absolute }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    /// Gốc server từ API_BASE_URL: `http://localhost:8081/api` → `http://localhost:8081/`.
    static func serverOrigin(of baseURL: URL) -> URL {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = "/"
        return components.url ?? baseURL
    }
}

private extension Optional where Wrapped == String {
    /// Bỏ chuỗi rỗng/chỉ có khoảng trắng về nil.
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Ghi tiến độ

/// Body `POST v1/hsk/reviews` (1–100 thẻ, áp dụng theo thứ tự gửi).
struct HSKReviewRequestDTO: Encodable, Equatable {
    struct Item: Encodable, Equatable {
        let level: Int
        let entryNumber: Int
        let result: String
    }

    let items: [Item]
}

struct HSKReviewResponseDTO: Decodable, Equatable {
    let items: [HSKWordProgressDTO]
    let levels: [HSKLevelDTO]?
}

/// Body `PUT v1/hsk/levels/{level}/words/{entryNumber}/progress`.
struct HSKProgressPutDTO: Encodable, Equatable {
    let status: String
}

struct HSKProgressResponseDTO: Decodable, Equatable {
    let word: HSKWordProgressDTO
    let level: HSKLevelDTO?
}

struct HSKWordProgressDTO: Decodable, Equatable {
    let level: Int
    let entryNumber: Int
    let status: String?
    let correctStreak: Int?
    let dueAt: String?
    let lastReviewedAt: String?

    var wordID: String { HSKVocabularyMapping.wordID(level: level, entryNumber: entryNumber) }
    var domainStatus: VocabStatus { HSKVocabularyMapping.status(status) }
}

// MARK: - Thẻ ghi nhớ

struct HSKFlashcardDeckDTO: Decodable, Equatable {
    let level: Int
    let items: [HSKFlashcardItemDTO]
    let dueCount: Int?
    let newCount: Int?
    let nextDueAt: String?

    func toDomain(audioBaseURL: URL) -> FlashcardDeck {
        FlashcardDeck(
            cards: items.map { $0.toDomain(level: level, audioBaseURL: audioBaseURL) },
            dueCount: dueCount ?? 0,
            newCount: newCount ?? 0,
            nextDueAt: HSKVocabularyMapping.date(nextDueAt)
        )
    }
}

struct HSKFlashcardItemDTO: Decodable, Equatable {
    let entryNumber: Int
    let hanzi: String
    let pinyin: String
    let meaningVi: String
    let audioUrl: String?
    let status: String?
    let reason: String?
    let hanViet: String?
    let wordType: String?
    let example: HSKExampleDTO?
    let decomposition: [HSKDecompositionDTO]?

    func toDomain(level: Int, audioBaseURL: URL) -> Flashcard {
        Flashcard(
            word: VocabWord(
                id: HSKVocabularyMapping.wordID(level: level, entryNumber: entryNumber),
                level: level,
                entryNumber: entryNumber,
                hanzi: hanzi,
                pinyin: pinyin,
                meaning: meaningVi,
                partOfSpeech: wordType.nonEmpty,
                hanViet: hanViet.nonEmpty,
                examples: example.map {
                    [VocabExample(hanzi: $0.sentenceZh, pinyin: $0.pinyin ?? "", meaning: $0.translationVi ?? "", note: $0.note.nonEmpty)]
                } ?? [],
                decomposition: HSKDecompositionDTO.toDomain(decomposition),
                audioURL: HSKVocabularyMapping.audioURL(audioUrl, base: audioBaseURL),
                // Thẻ chỉ có ví dụ đầu tiên, chưa có cách dùng: mở chi tiết sẽ tải đủ.
                hasDetail: false
            ),
            status: HSKVocabularyMapping.status(status),
            reason: reason.flatMap(FlashcardReason.init(rawValue:))
        )
    }
}

extension HSKVocabularyMapping {
    /// ISO-8601 UTC, có hoặc không có phần giây lẻ.
    static func date(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}
