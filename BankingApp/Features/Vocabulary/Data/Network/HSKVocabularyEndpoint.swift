import Alamofire
import Foundation

/// `{API_BASE_URL}/v1/hsk/...`, cần access token (trạng thái học là của từng người).
enum HSKVocabularyEndpoint: Endpoint {
    case levels
    case words(level: Int, status: String?, page: Int, size: Int)
    case word(level: Int, entryNumber: Int)

    var path: String {
        switch self {
        case .levels:
            return "v1/hsk/levels"
        case .words(let level, _, _, _):
            return "v1/hsk/levels/\(level)/words"
        case .word(let level, let entryNumber):
            return "v1/hsk/levels/\(level)/words/\(entryNumber)"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [String: String]? {
        switch self {
        case .words(_, let status, let page, let size):
            var items = ["page": String(page), "size": String(size)]
            if let status { items["status"] = status }
            return items
        case .levels, .word:
            return nil
        }
    }
}
