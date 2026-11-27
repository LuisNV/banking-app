import Alamofire
import Foundation

/// `GET {API_BASE_URL}/v1/radicals?commonOnly=&q=&strokes=`.
enum RadicalsEndpoint: Endpoint {
    case list(RadicalQuery)

    var path: String { "v1/radicals" }
    var method: HTTPMethod { .get }

    var queryItems: [String: String]? {
        switch self {
        case .list(let query):
            var items: [String: String] = [:]
            if query.commonOnly { items["commonOnly"] = "true" }
            let search = query.search.trimmingCharacters(in: .whitespacesAndNewlines)
            if !search.isEmpty { items["q"] = search }
            if query.strokes != .all { items["strokes"] = query.strokes.rawValue }
            return items.isEmpty ? nil : items
        }
    }
}

struct RadicalListDTO: Decodable, Equatable {
    struct Item: Decodable, Equatable {
        struct Example: Decodable, Equatable {
            let hanzi: String
            let hanViet: String?
            let meaningVi: String?
        }

        let number: Int
        let symbol: String
        let canonical: String?
        let forms: [String]?
        let hanViet: String?
        let aliasVi: String?
        let meaningVi: String?
        let strokes: Int?
        let canonicalStrokes: Int?
        let common: Bool?
        let descriptionVi: String?
        let examples: [Example]?

        func toDomain() -> Radical {
            Radical(
                number: number,
                symbol: symbol,
                canonical: canonical ?? symbol,
                forms: forms ?? [symbol],
                hanViet: hanViet ?? "",
                alias: aliasVi.flatMap { $0.isEmpty ? nil : $0 },
                meaning: meaningVi ?? "",
                strokes: strokes ?? canonicalStrokes ?? 0,
                canonicalStrokes: canonicalStrokes,
                isCommon: common ?? false,
                description: descriptionVi.flatMap { $0.isEmpty ? nil : $0 },
                examples: (examples ?? []).map { .init(hanzi: $0.hanzi, hanViet: $0.hanViet, meaning: $0.meaningVi) }
            )
        }
    }

    let total: Int?
    let items: [Item]

    func toDomain() -> RadicalList {
        RadicalList(total: total ?? items.count, items: items.map { $0.toDomain() })
    }
}

final class RadicalsRepositoryImpl: RadicalsRepository, @unchecked Sendable {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func radicals(_ query: RadicalQuery) async throws -> RadicalList {
        try await client.request(RadicalsEndpoint.list(query), as: RadicalListDTO.self).toDomain()
    }
}

/// Dữ liệu mẫu (USE_MOCK_API = YES), lọc giống server.
struct MockRadicalsRepository: RadicalsRepository {
    private static let all: [Radical] = [
        make(1, "一", "一", "nhất", nil, "một", 1, false, [("二", "nhị", "hai"), ("三", "tam", "ba")]),
        make(9, "亻", "人", "nhân", "Nhân đứng", "người", 2, true, [("你", "nhĩ", "bạn"), ("他", "tha", "anh ấy"), ("休", "hưu", "nghỉ")]),
        make(30, "口", "口", "khẩu", nil, "miệng", 3, true, [("吃", "ngật", "ăn"), ("喝", "hát", "uống"), ("叫", "khiếu", "gọi")]),
        make(38, "女", "女", "nữ", nil, "phụ nữ", 3, true, [("妈", "ma", "mẹ"), ("好", "hảo", "tốt"), ("姐", "thư", "chị")]),
        make(85, "氵", "水", "thủy", "Ba chấm thủy", "nước", 3, true, [("河", "hà", "sông"), ("海", "hải", "biển"), ("洗", "tẩy", "rửa")]),
        make(75, "木", "木", "mộc", nil, "cây", 4, true, [("林", "lâm", "rừng"), ("桌", "trác", "bàn"), ("休", "hưu", "nghỉ")]),
        make(61, "心", "心", "tâm", nil, "tim", 4, true, [("想", "tưởng", "nghĩ"), ("您", "nâm", "ngài"), ("忙", "mang", "bận")]),
        make(167, "钅", "金", "kim", nil, "kim loại", 5, true, [("钱", "tiền", "tiền"), ("银", "ngân", "bạc"), ("铁", "thiết", "sắt")]),
    ]

    private static func make(
        _ number: Int, _ symbol: String, _ canonical: String, _ hanViet: String, _ alias: String?,
        _ meaning: String, _ strokes: Int, _ common: Bool, _ examples: [(String, String, String)]
    ) -> Radical {
        Radical(
            number: number, symbol: symbol, canonical: canonical, forms: symbol == canonical ? [symbol] : [symbol, canonical],
            hanViet: hanViet, alias: alias, meaning: meaning, strokes: strokes, canonicalStrokes: nil,
            isCommon: common, description: nil,
            examples: examples.map { .init(hanzi: $0.0, hanViet: $0.1, meaning: $0.2) }
        )
    }

    func radicals(_ query: RadicalQuery) async throws -> RadicalList {
        try await Task.sleep(for: .milliseconds(200))
        let search = query.search.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
        let items = Self.all.filter { radical in
            if query.commonOnly && !radical.isCommon { return false }
            switch query.strokes {
            case .all: break
            case .fivePlus: if radical.strokes < 5 { return false }
            default: if String(radical.strokes) != query.strokes.rawValue { return false }
            }
            guard !search.isEmpty else { return true }
            let haystack = [radical.symbol, radical.canonical, String(radical.number), radical.hanViet, radical.meaning, radical.alias ?? ""]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
            return haystack.contains(search)
        }
        return RadicalList(total: items.count, items: items)
    }
}
