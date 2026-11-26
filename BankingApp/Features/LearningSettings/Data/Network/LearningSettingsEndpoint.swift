import Alamofire
import Foundation

/// `{API_BASE_URL}/v1/users/me/learning-settings`, cần access token.
enum LearningSettingsEndpoint: Endpoint {
    case get
    case put(LearningSettingsPutDTO)

    var path: String { "v1/users/me/learning-settings" }

    var method: HTTPMethod {
        switch self {
        case .get: return .get
        case .put: return .put
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .get: return nil
        case .put(let dto): return dto
        }
    }
}
