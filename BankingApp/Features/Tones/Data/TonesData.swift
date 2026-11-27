import Alamofire
import Foundation

enum TonesEndpoint: Endpoint {
    case guide
    case practice

    var path: String {
        switch self {
        case .guide: return "v1/tones"
        case .practice: return "v1/tones/practice"
        }
    }

    var method: HTTPMethod { .get }
}

struct ToneGuideDTO: Decodable, Equatable {
    struct Tone: Decodable, Equatable {
        let number: Int
        let pinyin: String?
        let pitch: [Int]?
        let descriptionVi: String?
        let audioUrl: String?
    }

    let tones: [Tone]
    let sandhiTipVi: String?

    func toDomain(audioBaseURL: URL) -> ToneGuide {
        ToneGuide(
            tones: tones.sorted { $0.number < $1.number }.map {
                ToneInfo(
                    number: $0.number,
                    pinyin: $0.pinyin ?? "",
                    pitch: ($0.pitch ?? []).map { min(max($0, 1), 5) },
                    description: $0.descriptionVi ?? "",
                    audioURL: HSKVocabularyMapping.audioURL($0.audioUrl, base: audioBaseURL)
                )
            },
            sandhiTip: sandhiTipVi.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

struct TonePracticeDTO: Decodable, Equatable {
    struct Question: Decodable, Equatable {
        let hanzi: String
        let level: Int?
        let entryNumber: Int?
        let syllable: String
        let syllablePosition: Int?
        let audioUrl: String?
        let correctTone: Int
    }

    let questions: [Question]

    func toDomain(audioBaseURL: URL) -> [TonePracticeQuestion] {
        questions.enumerated().compactMap { index, question in
            // Chỉ chấm được thanh 1–4 (bốn lựa chọn trên màn).
            guard (1...4).contains(question.correctTone) else { return nil }
            return TonePracticeQuestion(
                id: "\(index)-\(question.hanzi)-\(question.syllablePosition ?? 1)",
                hanzi: question.hanzi,
                level: question.level,
                entryNumber: question.entryNumber,
                syllable: question.syllable,
                syllablePosition: question.syllablePosition ?? 1,
                audioURL: HSKVocabularyMapping.audioURL(question.audioUrl, base: audioBaseURL),
                correctTone: question.correctTone
            )
        }
    }
}

final class TonesRepositoryImpl: TonesRepository, @unchecked Sendable {
    private let client: APIClient
    private let audioBaseURL: URL

    init(client: APIClient, apiBaseURL: URL) {
        self.client = client
        self.audioBaseURL = HSKVocabularyMapping.serverOrigin(of: apiBaseURL)
    }

    func guide() async throws -> ToneGuide {
        try await client.request(TonesEndpoint.guide, as: ToneGuideDTO.self).toDomain(audioBaseURL: audioBaseURL)
    }

    func practice() async throws -> [TonePracticeQuestion] {
        try await client.request(TonesEndpoint.practice, as: TonePracticeDTO.self).toDomain(audioBaseURL: audioBaseURL)
    }
}

/// Dữ liệu mẫu (USE_MOCK_API = YES).
struct MockTonesRepository: TonesRepository {
    func guide() async throws -> ToneGuide {
        try await Task.sleep(for: .milliseconds(200))
        return ToneGuide(
            tones: [
                ToneInfo(number: 1, pinyin: "mā", pitch: [5, 5], description: "Cao và đều, giữ giọng ngang."),
                ToneInfo(number: 2, pinyin: "má", pitch: [3, 5], description: "Đi từ vừa lên cao, gần giống dấu sắc."),
                ToneInfo(number: 3, pinyin: "mǎ", pitch: [2, 1, 4], description: "Khi đọc riêng, giọng xuống thấp rồi đi lên."),
                ToneInfo(number: 4, pinyin: "mà", pitch: [5, 1], description: "Bắt đầu cao rồi hạ nhanh, dứt khoát."),
            ],
            sandhiTip: "Khi hai thanh 3 đứng liền nhau, thanh đầu đọc thành thanh 2. Ví dụ, nǐ hǎo đọc gần như ní hǎo."
        )
    }

    func practice() async throws -> [TonePracticeQuestion] {
        try await Task.sleep(for: .milliseconds(200))
        let items: [(String, String, Int, Int)] = [
            ("你好", "hao", 2, 3), ("妈妈", "ma", 1, 1), ("学习", "xue", 1, 2), ("谢谢", "xie", 1, 4),
            ("中国", "guo", 2, 2), ("老师", "shi", 2, 1), ("朋友", "peng", 1, 2), ("再见", "zai", 1, 4),
            ("水", "shui", 1, 3), ("吃", "chi", 1, 1),
        ]
        return items.enumerated().map { index, item in
            TonePracticeQuestion(
                id: "\(index)", hanzi: item.0, level: 1, entryNumber: nil,
                syllable: item.1, syllablePosition: item.2, audioURL: nil, correctTone: item.3
            )
        }
    }
}
