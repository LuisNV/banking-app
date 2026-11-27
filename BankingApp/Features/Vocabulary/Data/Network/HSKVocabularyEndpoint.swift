import Alamofire
import Foundation

/// `{API_BASE_URL}/v1/hsk/...`, cần access token (trạng thái học là của từng người).
enum HSKVocabularyEndpoint: Endpoint {
    case levels
    case words(level: Int, status: String?, page: Int, size: Int)
    case word(level: Int, entryNumber: Int)
    case flashcards(level: Int, size: Int)
    case wordOfTheDay
    case reviews(HSKReviewRequestDTO)
    case progress(level: Int, entryNumber: Int, body: HSKProgressPutDTO)

    var path: String {
        switch self {
        case .levels:
            return "v1/hsk/levels"
        case .words(let level, _, _, _):
            return "v1/hsk/levels/\(level)/words"
        case .word(let level, let entryNumber):
            return "v1/hsk/levels/\(level)/words/\(entryNumber)"
        case .flashcards(let level, _):
            return "v1/hsk/levels/\(level)/flashcards"
        case .wordOfTheDay:
            return "v1/hsk/word-of-the-day"
        case .reviews:
            return "v1/hsk/reviews"
        case .progress(let level, let entryNumber, _):
            return "v1/hsk/levels/\(level)/words/\(entryNumber)/progress"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .levels, .words, .word, .flashcards, .wordOfTheDay: return .get
        case .reviews: return .post
        case .progress: return .put
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .reviews(let dto): return dto
        case .progress(_, _, let dto): return dto
        case .levels, .words, .word, .flashcards, .wordOfTheDay: return nil
        }
    }

    var queryItems: [String: String]? {
        switch self {
        case .words(_, let status, let page, let size):
            var items = ["page": String(page), "size": String(size)]
            if let status { items["status"] = status }
            return items
        case .flashcards(_, let size):
            return ["size": String(size)]
        case .levels, .word, .reviews, .progress, .wordOfTheDay:
            return nil
        }
    }
}
