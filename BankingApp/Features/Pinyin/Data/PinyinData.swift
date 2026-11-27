import Alamofire
import Foundation

enum PinyinEndpoint: Endpoint {
    case chart

    var path: String { "v1/pinyin/chart" }
    var method: HTTPMethod { .get }
}

struct PinyinChartDTO: Decodable, Equatable {
    let initials: [PinyinGroupDTO]?
    let finals: [PinyinGroupDTO]?
    let combinations: [PinyinCombinationDTO]?

    func toDomain(audioBaseURL: URL) -> PinyinChart {
        func groups(_ items: [PinyinGroupDTO]?, prefix: String) -> [PinyinGroup] {
            (items ?? []).enumerated().compactMap { index, group in
                let sounds = (group.items ?? []).map { $0.toDomain(audioBaseURL: audioBaseURL) }
                guard !sounds.isEmpty else { return nil }
                return PinyinGroup(id: "\(prefix)-\(index)", title: group.titleVi ?? "", sounds: sounds)
            }
        }
        return PinyinChart(
            initials: groups(initials, prefix: "initials"),
            finals: groups(finals, prefix: "finals"),
            combinations: (combinations ?? []).map {
                PinyinCombination(initial: $0.initial ?? "", final: $0.finalSymbol, syllable: $0.syllable)
            }
        )
    }
}

struct PinyinGroupDTO: Decodable, Equatable {
    let titleVi: String?
    let items: [PinyinSoundDTO]?
}

struct PinyinSoundDTO: Decodable, Equatable {
    let symbol: String
    let pinyin: String?
    let hanzi: String?
    let meaningVi: String?
    let tipVi: String?
    let audioUrl: String?

    func toDomain(audioBaseURL: URL) -> PinyinSound {
        PinyinSound(
            symbol: symbol,
            examplePinyin: pinyin.flatMap { $0.isEmpty ? nil : $0 },
            exampleHanzi: hanzi.flatMap { $0.isEmpty ? nil : $0 },
            meaning: meaningVi.flatMap { $0.isEmpty ? nil : $0 },
            tip: tipVi.flatMap { $0.isEmpty ? nil : $0 },
            audioURL: HSKVocabularyMapping.audioURL(audioUrl, base: audioBaseURL)
        )
    }
}

struct PinyinCombinationDTO: Decodable, Equatable {
    let initial: String?
    let finalSymbol: String
    let syllable: String
}

final class PinyinRepositoryImpl: PinyinRepository, @unchecked Sendable {
    private let client: APIClient
    /// Gốc server để ghép `audioUrl` ("/audio/…").
    private let audioBaseURL: URL

    init(client: APIClient, apiBaseURL: URL) {
        self.client = client
        self.audioBaseURL = HSKVocabularyMapping.serverOrigin(of: apiBaseURL)
    }

    func chart() async throws -> PinyinChart {
        try await client.request(PinyinEndpoint.chart, as: PinyinChartDTO.self).toDomain(audioBaseURL: audioBaseURL)
    }
}

/// Dữ liệu mẫu (USE_MOCK_API = YES): một phần bảng để dựng giao diện.
struct MockPinyinRepository: PinyinRepository {
    func chart() async throws -> PinyinChart {
        try await Task.sleep(for: .milliseconds(250))
        func sound(_ symbol: String, _ pinyin: String, _ hanzi: String, _ meaning: String, _ tip: String) -> PinyinSound {
            PinyinSound(symbol: symbol, examplePinyin: pinyin, exampleHanzi: hanzi, meaning: meaning, tip: tip)
        }
        let initials = [
            PinyinGroup(id: "i0", title: "Âm môi", sounds: [
                sound("b", "bā", "八", "tám", "Như “p” tiếng Việt nhưng không bật hơi."),
                sound("p", "pà", "怕", "sợ", "Như “p” nhưng bật mạnh hơi ra."),
                sound("m", "mā", "妈", "mẹ", "Như “m” tiếng Việt."),
                sound("f", "fàn", "饭", "cơm", "Như “ph” tiếng Việt."),
            ]),
            PinyinGroup(id: "i1", title: "Đầu lưỡi · Cuống lưỡi", sounds: [
                sound("d", "dà", "大", "to", "Như “t” không bật hơi."),
                sound("t", "tā", "他", "anh ấy", "Như “th” bật hơi mạnh."),
                sound("n", "nǐ", "你", "bạn", "Như “n” tiếng Việt."),
                sound("l", "lái", "来", "đến", "Như “l” tiếng Việt."),
                sound("g", "gē", "哥", "anh trai", "Như “c/k” không bật hơi."),
                sound("k", "kàn", "看", "xem", "Như “kh” nhưng bật hơi."),
                sound("h", "hǎo", "好", "tốt", "Như “h” nhưng phát từ cuống họng."),
            ]),
            PinyinGroup(id: "i2", title: "Mặt lưỡi · Đầu lưỡi sau · Đầu lưỡi trước", sounds: [
                sound("j", "jiā", "家", "nhà", "Như “ch” nhẹ, mặt lưỡi chạm ngạc."),
                sound("q", "qù", "去", "đi", "Như “j” nhưng bật hơi."),
                sound("x", "xiè", "谢", "cảm ơn", "Như “x” tiếng Việt, môi dẹt."),
                sound("zh", "zhōng", "中", "giữa", "Hơi cong đầu lưỡi về phía sau lợi trên rồi nhả nhẹ."),
                sound("ch", "chī", "吃", "ăn", "Như “zh” nhưng bật hơi mạnh."),
                sound("sh", "shì", "是", "là", "Như “s” tiếng Việt (cong lưỡi)."),
                sound("r", "rén", "人", "người", "Như “r” nhẹ, cong lưỡi."),
                sound("z", "zài", "在", "ở", "Như “ch” đầu lưỡi thẳng, không bật hơi."),
                sound("c", "cài", "菜", "món ăn", "Như “z” nhưng bật hơi."),
                sound("s", "sān", "三", "ba", "Như “x” tiếng Việt."),
            ]),
        ]
        let finals = [
            PinyinGroup(id: "f0", title: "Vận mẫu đơn", sounds: [
                sound("a", "mā", "妈", "mẹ", "Như “a”."),
                sound("o", "wǒ", "我", "tôi", "Như “ua” lướt nhanh."),
                sound("e", "hē", "喝", "uống", "Như “ơ” lùi sâu trong họng."),
                sound("i", "nǐ", "你", "bạn", "Như “i”."),
                sound("u", "bù", "不", "không", "Như “u”."),
                sound("ü", "lǜ", "绿", "xanh lá", "Tròn môi nói “i”, gần “uy”."),
            ]),
            PinyinGroup(id: "f1", title: "Vận mẫu mũi sau", sounds: [
                sound("ang", "máng", "忙", "bận", "Như “ang”."),
                sound("eng", "lěng", "冷", "lạnh", "Như “âng”."),
                sound("ong", "zhōng", "中", "giữa", "Tròn môi và kết thúc bằng ng."),
            ]),
        ]
        var combinations: [PinyinCombination] = []
        for initial in ["b", "m", "d", "zh"] {
            for final in ["a", "ai", "ang", "eng", "ong", "u"] where !(initial == "b" && final == "ong") && !(initial == "m" && final == "ong") {
                combinations.append(PinyinCombination(initial: initial, final: final, syllable: initial + final))
            }
        }
        combinations.append(PinyinCombination(initial: "j", final: "ü", syllable: "ju"))
        return PinyinChart(initials: initials, finals: finals, combinations: combinations)
    }
}
